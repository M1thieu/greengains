import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import crypto from 'crypto';
import { getPool } from '../database';
import { verifyFirebaseToken } from '../utils/firebase-auth';

/**
 * Referral endpoints — all backed by the single `referrals` table.
 *
 * event_type discriminator:
 *   'code'    — one row per user, their stable GG-XXXXX code
 *   'invite'  — appended each time owner copies/shares their link
 *   'convert' — appended when a new user signs up via a referral link
 */
export async function referralRoutes(fastify: FastifyInstance) {
  const REFERRAL_CODE_PATTERN = /^GG-[A-Z0-9]{5}$/;
  // Unambiguous alphabet: no 0/O, 1/I confusion
  const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  function generateReferralCode(): string {
    const bytes = crypto.randomBytes(5);
    return 'GG-' + Array.from(bytes)
      .map((b) => CODE_ALPHABET[b % CODE_ALPHABET.length])
      .join('');
  }

  function normalizeCode(input: string | undefined): string | null {
    if (!input) return null;
    const code = input.trim().toUpperCase();
    return REFERRAL_CODE_PATTERN.test(code) ? code : null;
  }

  /**
   * Get or create a stable referral code for this user.
   * Uses the 'code' event_type row in the unified referrals table.
   */
  async function getOrCreateCode(uid: string): Promise<string> {
    const pool = getPool();

    // Fast path: code already exists
    const existing = await pool.query<{ referral_code: string }>(
      `SELECT referral_code FROM referrals WHERE owner_uid = $1 AND event_type = 'code'`,
      [uid],
    );
    if (existing.rows.length > 0) return existing.rows[0].referral_code;

    // Slow path: allocate a new code with collision retry
    for (let attempt = 0; attempt < 8; attempt++) {
      const code = generateReferralCode();
      try {
        const row = await pool.query<{ referral_code: string }>(
          `INSERT INTO referrals (event_type, referral_code, owner_uid)
           VALUES ('code', $2, $1)
           ON CONFLICT (owner_uid) WHERE event_type = 'code'
           DO UPDATE SET referral_code = referrals.referral_code
           RETURNING referral_code`,
          [uid, code],
        );
        if (row.rows.length > 0) return row.rows[0].referral_code;
      } catch (err: any) {
        if (err?.code === '23505') continue; // referral_code collision — retry
        throw err;
      }
    }
    throw new Error('Unable to allocate referral code after 8 attempts');
  }

  // ─── Routes ──────────────────────────────────────────────────────────────

  /**
   * GET /api/v1/referrals/code
   * Returns the caller's stable referral code, creating it on first call.
   */
  fastify.get('/api/v1/referrals/code', async (req: FastifyRequest, reply: FastifyReply) => {
    let uid: string | null = null;
    try {
      uid = await verifyFirebaseToken(req, reply);
      if (reply.sent || !uid) return;
    } catch {
      return reply.code(401).send({ error: 'Unauthorized' });
    }

    try {
      return reply.send({ referralCode: await getOrCreateCode(uid) });
    } catch (err) {
      fastify.log.error(err, 'getOrCreateCode failed');
      return reply.code(500).send({ error: 'Internal error' });
    }
  });

  /**
   * POST /api/v1/referrals/invite
   * Logged whenever the owner copies/shares their referral link.
   * Body: { referralCode: string }
   */
  fastify.post('/api/v1/referrals/invite', async (req: FastifyRequest, reply: FastifyReply) => {
    let uid: string | null = null;
    try {
      uid = await verifyFirebaseToken(req, reply);
      if (reply.sent || !uid) return;
    } catch {
      return reply.code(401).send({ error: 'Unauthorized' });
    }

    const body = req.body as { referralCode?: string };
    const code = normalizeCode(body.referralCode);
    if (!code) return reply.code(400).send({ error: 'Invalid referralCode format' });

    try {
      // Verify the code belongs to the caller — prevent spoofing
      const owns = await getPool().query(
        `SELECT 1 FROM referrals WHERE owner_uid = $1 AND referral_code = $2 AND event_type = 'code'`,
        [uid, code],
      );
      if (owns.rows.length === 0) {
        return reply.code(403).send({ error: 'Referral code not owned by caller' });
      }

      await getPool().query(
        `INSERT INTO referrals (event_type, referral_code, owner_uid) VALUES ('invite', $1, $2)`,
        [code, uid],
      );
      return reply.send({ ok: true });
    } catch (err) {
      fastify.log.error(err, 'referral invite failed');
      return reply.code(500).send({ error: 'Internal error' });
    }
  });

  /**
   * POST /api/v1/referrals/convert
   * Logged when a new user signs up via a referral link.
   * Body: { referralCode: string }
   * Idempotent — one conversion per invitee (partial unique index).
   */
  fastify.post('/api/v1/referrals/convert', async (req: FastifyRequest, reply: FastifyReply) => {
    let uid: string | null = null;
    try {
      uid = await verifyFirebaseToken(req, reply);
      if (reply.sent || !uid) return;
    } catch {
      return reply.code(401).send({ error: 'Unauthorized' });
    }

    const body = req.body as { referralCode?: string };
    const code = normalizeCode(body.referralCode);
    if (!code) return reply.code(400).send({ error: 'Invalid referralCode format' });

    try {
      const owner = await getPool().query<{ owner_uid: string }>(
        `SELECT owner_uid FROM referrals WHERE referral_code = $1 AND event_type = 'code'`,
        [code],
      );
      if (owner.rows.length === 0) return reply.code(404).send({ error: 'Unknown referral code' });

      const inviterUid = owner.rows[0].owner_uid;
      if (inviterUid === uid) return reply.code(409).send({ error: 'Self-referral not allowed' });

      await getPool().query(
        `INSERT INTO referrals (event_type, referral_code, owner_uid, actor_uid)
         VALUES ('convert', $1, $2, $3)
         ON CONFLICT (actor_uid) WHERE event_type = 'convert' DO NOTHING`,
        [code, inviterUid, uid],
      );
      return reply.send({ ok: true });
    } catch (err) {
      fastify.log.error(err, 'referral convert failed');
      return reply.code(500).send({ error: 'Internal error' });
    }
  });

  /**
   * GET /api/v1/referrals/stats
   * Returns invite share count and conversion count for the caller.
   */
  fastify.get('/api/v1/referrals/stats', async (req: FastifyRequest, reply: FastifyReply) => {
    let uid: string | null = null;
    try {
      uid = await verifyFirebaseToken(req, reply);
      if (reply.sent || !uid) return;
    } catch {
      return reply.code(401).send({ error: 'Unauthorized' });
    }

    try {
      const { rows } = await getPool().query(
        `SELECT
           COUNT(*) FILTER (WHERE event_type = 'invite')  AS invites_shared,
           COUNT(*) FILTER (WHERE event_type = 'convert') AS conversions
         FROM referrals
         WHERE owner_uid = $1`,
        [uid],
      );
      return reply.send({
        invitesShared: parseInt(rows[0].invites_shared, 10) || 0,
        conversions:   parseInt(rows[0].conversions,   10) || 0,
      });
    } catch (err) {
      fastify.log.error(err, 'referral stats failed');
      return reply.code(500).send({ error: 'Internal error' });
    }
  });
}
