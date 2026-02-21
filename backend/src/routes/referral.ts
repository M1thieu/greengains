import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { getPool } from '../database';
import { verifyFirebaseToken } from '../utils/firebase-auth';

/**
 * Referral endpoints — log invite shares and conversion events.
 * The referral code is generated client-side as a deterministic hash of the
 * user's Firebase UID (GG-XXXXX format). No server-side code generation needed.
 */
export async function referralRoutes(fastify: FastifyInstance) {

  /**
   * POST /api/v1/referrals/invite
   * Logged when a user copies their referral link.
   * Body: { referralCode: string }
   */
  fastify.post(
    '/api/v1/referrals/invite',
    async (request: FastifyRequest, reply: FastifyReply) => {
      let uid: string | null = null;
      try {
        uid = await verifyFirebaseToken(request, reply);
        if (reply.sent || !uid) return;
      } catch {
        return reply.code(401).send({ error: 'Unauthorized' });
      }

      const { referralCode } = request.body as { referralCode?: string };
      if (!referralCode) {
        return reply.code(400).send({ error: 'referralCode required' });
      }

      try {
        await getPool().query(
          `INSERT INTO referral_events (event_type, referral_code, actor_uid)
           VALUES ('invite', $1, $2)`,
          [referralCode, uid]
        );
        return reply.send({ ok: true });
      } catch (err) {
        fastify.log.error(err, 'Failed to record referral invite');
        return reply.code(500).send({ error: 'Internal error' });
      }
    }
  );

  /**
   * POST /api/v1/referrals/convert
   * Logged when a new user signs up via a referral link.
   * Body: { referralCode: string }
   */
  fastify.post(
    '/api/v1/referrals/convert',
    async (request: FastifyRequest, reply: FastifyReply) => {
      let uid: string | null = null;
      try {
        uid = await verifyFirebaseToken(request, reply);
        if (reply.sent || !uid) return;
      } catch {
        return reply.code(401).send({ error: 'Unauthorized' });
      }

      const { referralCode } = request.body as { referralCode?: string };
      if (!referralCode) {
        return reply.code(400).send({ error: 'referralCode required' });
      }

      try {
        // Idempotent — one conversion per invitee (partial unique index on actor_uid WHERE convert)
        await getPool().query(
          `INSERT INTO referral_events (event_type, referral_code, actor_uid)
           VALUES ('convert', $1, $2)
           ON CONFLICT (actor_uid) WHERE event_type = 'convert' DO NOTHING`,
          [referralCode, uid]
        );
        return reply.send({ ok: true });
      } catch (err) {
        fastify.log.error(err, 'Failed to record referral conversion');
        return reply.code(500).send({ error: 'Internal error' });
      }
    }
  );

  /**
   * GET /api/v1/referrals/stats
   * Returns how many invites this user has shared and how many converted.
   */
  fastify.get(
    '/api/v1/referrals/stats',
    async (request: FastifyRequest, reply: FastifyReply) => {
      let uid: string | null = null;
      try {
        uid = await verifyFirebaseToken(request, reply);
        if (reply.sent || !uid) return;
      } catch {
        return reply.code(401).send({ error: 'Unauthorized' });
      }

      try {
        const { rows } = await getPool().query(
          `SELECT
             COUNT(*) FILTER (WHERE event_type = 'invite')  AS invites_shared,
             COUNT(*) FILTER (WHERE event_type = 'convert') AS conversions
           FROM referral_events
           WHERE actor_uid = $1`,
          [uid]
        );
        return reply.send({
          invitesShared: parseInt(rows[0].invites_shared) || 0,
          conversions:   parseInt(rows[0].conversions)    || 0,
        });
      } catch (err) {
        fastify.log.error(err, 'Failed to fetch referral stats');
        return reply.code(500).send({ error: 'Internal error' });
      }
    }
  );
}
