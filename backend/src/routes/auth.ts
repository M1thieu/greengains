import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import { getPool } from '../database';
import { verifyFirebaseToken } from '../utils/firebase-auth';
import crypto from 'crypto';

/**
 * Auth Routes - Organization & Subscription Management
 * All endpoints require Firebase authentication
 */
export async function authRoutes(fastify: FastifyInstance) {
  const pool = getPool();

  /**
   * GET /api/v1/auth/me
   * Get current user profile + organizations + subscription tier
   *
   * Returns: {
   *   uid: string,
   *   email: string,
   *   organizations: [{ id, name, role, subscription_tier }],
   *   primary_organization_id: UUID (user's default org)
   * }
   */
  fastify.get(
    '/api/v1/auth/me',
    { preHandler: (req, reply) => verifyFirebaseToken(req, reply) },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request as any).user?.uid;
      if (!userId) {
        return reply.code(401).send({ error: 'Unauthorized' });
      }

      try {
        // Get user's organizations
        const orgsResult = await pool.query(
          `SELECT
            o.id, o.name, o.slug, o.description,
            om.role,
            s.tier as subscription_tier,
            om.accepted_at IS NOT NULL as is_active_member
          FROM organization_members om
          JOIN organizations o ON om.organization_id = o.id
          LEFT JOIN subscriptions s ON o.id = s.organization_id
          WHERE om.user_id = $1
            AND om.accepted_at IS NOT NULL
            AND o.deleted_at IS NULL
          ORDER BY om.created_at ASC`,
          [userId]
        );

        // If no orgs, create a default personal org
        let organizations = orgsResult.rows;
        let primaryOrgId = organizations[0]?.id;

        if (organizations.length === 0) {
          // Create personal organization
          const personalOrg = await pool.query(
            `INSERT INTO organizations (name, slug, created_by)
            VALUES ($1, $2, $3)
            RETURNING id, name, slug`,
            [`Personal (${userId.slice(0, 8)})`, `personal-${crypto.randomBytes(4).toString('hex')}`, userId]
          );

          const orgId = personalOrg.rows[0].id;
          primaryOrgId = orgId;

          // Add user as admin of personal org
          await pool.query(
            `INSERT INTO organization_members (organization_id, user_id, email, role, accepted_at)
            VALUES ($1, $2, $3, $4, NOW())`,
            [orgId, userId, (request as any).user?.email || 'unknown@example.com', 'admin']
          );

          // Create free subscription
          await pool.query(
            `INSERT INTO subscriptions (organization_id, tier, status)
            VALUES ($1, $2, $3)`,
            [orgId, 'free', 'active']
          );

          organizations = [
            {
              id: orgId,
              name: personalOrg.rows[0].name,
              slug: personalOrg.rows[0].slug,
              role: 'admin',
              subscription_tier: 'free',
              is_active_member: true,
            },
          ];
        }

        return reply.send({
          uid: userId,
          email: (request as any).user?.email,
          organizations,
          primary_organization_id: primaryOrgId,
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    }
  );

  /**
   * GET /api/v1/organizations
   * List user's organizations
   */
  fastify.get(
    '/api/v1/organizations',
    { preHandler: (req, reply) => verifyFirebaseToken(req, reply) },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request as any).user?.uid;

      try {
        const result = await pool.query(
          `SELECT
            o.id, o.name, o.slug, o.description, o.logo_url,
            om.role,
            s.tier as subscription_tier,
            s.status as subscription_status,
            COUNT(*) FILTER (WHERE om.accepted_at IS NOT NULL) as member_count
          FROM organization_members om
          JOIN organizations o ON om.organization_id = o.id
          LEFT JOIN subscriptions s ON o.id = s.organization_id
          WHERE om.user_id = $1
            AND om.accepted_at IS NOT NULL
            AND o.deleted_at IS NULL
          GROUP BY o.id, om.role, s.tier, s.status
          ORDER BY om.created_at ASC`,
          [userId]
        );

        return reply.send({ organizations: result.rows });
      } catch (error) {
        fastify.log.error(error);
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    }
  );

  /**
   * POST /api/v1/organizations
   * Create a new organization
   */
  const createOrgSchema = z.object({
    name: z.string().min(1).max(255),
    description: z.string().max(1000).optional(),
  });

  fastify.post(
    '/api/v1/organizations',
    { preHandler: (req, reply) => verifyFirebaseToken(req, reply) },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request as any).user?.uid;

      try {
        const body = createOrgSchema.parse(request.body);
        const slug = `${body.name
          .toLowerCase()
          .replace(/[^a-z0-9]/g, '-')
          .slice(0, 50)}-${crypto.randomBytes(3).toString('hex')}`;

        const result = await pool.query(
          `INSERT INTO organizations (name, slug, description, created_by)
          VALUES ($1, $2, $3, $4)
          RETURNING id, name, slug`,
          [body.name, slug, body.description || null, userId]
        );

        const orgId = result.rows[0].id;

        // Add creator as admin
        await pool.query(
          `INSERT INTO organization_members (organization_id, user_id, email, role, accepted_at)
          VALUES ($1, $2, $3, $4, NOW())`,
          [orgId, userId, (request as any).user?.email || 'unknown@example.com', 'admin']
        );

        // Create free subscription by default
        await pool.query(
          `INSERT INTO subscriptions (organization_id, tier, status)
          VALUES ($1, $2, $3)`,
          [orgId, 'free', 'active']
        );

        // Log audit event
        await pool.query(
          `INSERT INTO audit_log (organization_id, user_id, action, resource_type, resource_id)
          VALUES ($1, $2, $3, $4, $5)`,
          [orgId, userId, 'organization_created', 'organization', orgId]
        );

        return reply.code(201).send(result.rows[0]);
      } catch (error) {
        if (error instanceof z.ZodError) {
          return reply.code(422).send({ error: 'Validation Error', details: error.errors });
        }
        fastify.log.error(error);
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    }
  );

  /**
   * GET /api/v1/organizations/:orgId/subscription
   * Get subscription details for an organization
   */
  fastify.get(
    '/api/v1/organizations/:orgId/subscription',
    { preHandler: (req, reply) => verifyFirebaseToken(req, reply) },
    async (request: FastifyRequest<{ Params: { orgId: string } }>, reply: FastifyReply) => {
      const userId = (request as any).user?.uid;
      const { orgId } = request.params;

      try {
        // Verify user is member of org
        const memberCheck = await pool.query(
          `SELECT role FROM organization_members
          WHERE organization_id = $1 AND user_id = $2 AND accepted_at IS NOT NULL`,
          [orgId, userId]
        );

        if (memberCheck.rows.length === 0) {
          return reply.code(403).send({ error: 'Forbidden' });
        }

        // Get subscription + features
        const subResult = await pool.query(
          `SELECT
            s.id, s.tier, s.status,
            s.billing_email, s.current_period_start, s.current_period_end,
            s.cancel_at_period_end,
            json_agg(json_build_object(
              'feature_name', sf.feature_name,
              'feature_value', sf.feature_value
            )) as features
          FROM subscriptions s
          LEFT JOIN subscription_features sf ON s.id = sf.subscription_id
          WHERE s.organization_id = $1
          GROUP BY s.id`,
          [orgId]
        );

        if (subResult.rows.length === 0) {
          return reply.code(404).send({ error: 'Subscription not found' });
        }

        return reply.send(subResult.rows[0]);
      } catch (error) {
        fastify.log.error(error);
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    }
  );

  /**
   * POST /api/v1/organizations/:orgId/api-keys
   * Create an API key for programmatic access
   */
  const createApiKeySchema = z.object({
    name: z.string().min(1).max(255),
  });

  fastify.post(
    '/api/v1/organizations/:orgId/api-keys',
    { preHandler: (req, reply) => verifyFirebaseToken(req, reply) },
    async (request: FastifyRequest<{ Params: { orgId: string } }>, reply: FastifyReply) => {
      const userId = (request as any).user?.uid;
      const { orgId } = request.params;

      try {
        // Verify user is admin of org
        const memberCheck = await pool.query(
          `SELECT role FROM organization_members
          WHERE organization_id = $1 AND user_id = $2 AND role = 'admin' AND accepted_at IS NOT NULL`,
          [orgId, userId]
        );

        if (memberCheck.rows.length === 0) {
          return reply.code(403).send({ error: 'Forbidden - Admin only' });
        }

        const body = createApiKeySchema.parse(request.body);

        // Generate API key: sk_live_<32 random chars>
        const apiKey = `sk_live_${crypto.randomBytes(16).toString('hex')}`;
        const keyHash = crypto.createHash('sha256').update(apiKey).digest('hex');
        const keyPreview = `sk_live_${apiKey.slice(-4)}`;

        const result = await pool.query(
          `INSERT INTO api_keys (organization_id, name, key_hash, key_preview, created_by)
          VALUES ($1, $2, $3, $4, $5)
          RETURNING id, name, key_preview, created_at`,
          [orgId, body.name, keyHash, keyPreview, userId]
        );

        // Log audit event
        await pool.query(
          `INSERT INTO audit_log (organization_id, user_id, action, resource_type, resource_id, details)
          VALUES ($1, $2, $3, $4, $5, $6)`,
          [orgId, userId, 'api_key_created', 'api_key', result.rows[0].id, { name: body.name }]
        );

        return reply.code(201).send({
          ...result.rows[0],
          api_key: apiKey, // Only returned once!
          warning: 'Save this API key somewhere safe. You won\'t be able to see it again.',
        });
      } catch (error) {
        if (error instanceof z.ZodError) {
          return reply.code(422).send({ error: 'Validation Error', details: error.errors });
        }
        fastify.log.error(error);
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    }
  );

  /**
   * GET /api/v1/organizations/:orgId/members
   * List organization members
   */
  fastify.get(
    '/api/v1/organizations/:orgId/members',
    { preHandler: (req, reply) => verifyFirebaseToken(req, reply) },
    async (request: FastifyRequest<{ Params: { orgId: string } }>, reply: FastifyReply) => {
      const userId = (request as any).user?.uid;
      const { orgId } = request.params;

      try {
        // Verify user is member of org
        const memberCheck = await pool.query(
          `SELECT role FROM organization_members
          WHERE organization_id = $1 AND user_id = $2 AND accepted_at IS NOT NULL`,
          [orgId, userId]
        );

        if (memberCheck.rows.length === 0) {
          return reply.code(403).send({ error: 'Forbidden' });
        }

        const result = await pool.query(
          `SELECT id, user_id, email, role, invited_at, accepted_at
          FROM organization_members
          WHERE organization_id = $1
          ORDER BY created_at ASC`,
          [orgId]
        );

        return reply.send({ members: result.rows });
      } catch (error) {
        fastify.log.error(error);
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    }
  );
}
