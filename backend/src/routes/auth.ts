import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { getPool } from '../database';
import { verifyFirebaseToken } from '../utils/firebase-auth';
import { getOrgSubscriptionTier, ensureUserTier, TIER_HISTORY_DAYS } from '../utils/tier-utils';

/**
 * Auth Routes
 * GET /api/v1/auth/me — returns uid, email, tier, data_retention_days.
 * Creates a free-tier row on first call if one doesn't exist yet.
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
        await ensureUserTier(pool, userId);
        const tier = await getOrgSubscriptionTier(pool, userId);

        return reply.send({
          uid: userId,
          email: (request as any).user?.email ?? null,
          tier,
          data_retention_days: TIER_HISTORY_DAYS[tier],
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    }
  );
}
