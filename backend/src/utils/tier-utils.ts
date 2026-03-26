import { Pool } from 'pg';
import { FastifyRequest, FastifyReply } from 'fastify';
import { getPool } from '../database';

/**
 * Subscription tier helpers — single source of truth for tier limits.
 * Uses user_tiers table (simple: user_id → tier).
 */

export type SubscriptionTier = 'free' | 'pro' | 'enterprise'

/** Max data history in days per tier. */
export const TIER_HISTORY_DAYS: Record<SubscriptionTier, number> = {
  free:       7,
  pro:        90,
  enterprise: 365,
}

/** Max export rows per tier (0 = blocked). */
export const TIER_EXPORT_ROWS: Record<SubscriptionTier, number> = {
  free:       0,
  pro:        100_000,
  enterprise: 1_000_000,
}

function isTier(value: unknown): value is SubscriptionTier {
  return value === 'free' || value === 'pro' || value === 'enterprise'
}

/**
 * Look up the subscription tier for a Firebase user.
 * Returns 'free' if no row exists or if the query fails.
 */
export async function getOrgSubscriptionTier(
  pool: Pool,
  userId: string
): Promise<SubscriptionTier> {
  try {
    const result = await pool.query(
      'SELECT tier FROM user_tiers WHERE user_id = $1',
      [userId]
    )
    const tier = result.rows[0]?.tier
    return isTier(tier) ? tier : 'free'
  } catch (error) {
    console.warn('Could not determine subscription tier, defaulting to free:', error)
    return 'free'
  }
}

/**
 * Ensure a user_tiers row exists for this user (upsert to free if missing).
 */
export async function ensureUserTier(pool: Pool, userId: string): Promise<void> {
  await pool.query(
    `INSERT INTO user_tiers (user_id, tier) VALUES ($1, 'free')
     ON CONFLICT (user_id) DO NOTHING`,
    [userId]
  )
}

/** Numeric rank for tier comparison: free < pro < enterprise. */
const TIER_RANK: Record<SubscriptionTier, number> = { free: 0, pro: 1, enterprise: 2 };

/**
 * Fastify preHandler factory that enforces a minimum subscription tier.
 * Must run after requireFirebaseAuth so that request.user is populated.
 *
 * Usage: { preHandler: [requireFirebaseAuth, requireTier('pro')] }
 *
 * Inspired by DIMO data-sdk: declare access requirements at the route
 * definition level, not inline inside handler logic.
 */
export function requireTier(minTier: SubscriptionTier) {
  return async function tierPreHandler(request: FastifyRequest, reply: FastifyReply): Promise<void> {
    const userId = request.user?.uid;
    if (!userId) {
      reply.code(401).send({ error: 'Unauthorized' });
      return;
    }
    const pool = getPool();
    const tier = await getOrgSubscriptionTier(pool, userId);
    if (TIER_RANK[tier] < TIER_RANK[minTier]) {
      reply.code(403).send({
        error: 'Subscription required',
        required_tier: minTier,
        current_tier: tier,
        message: `This endpoint requires a ${minTier} subscription or higher.`,
      });
    }
  };
}

export function getMaxHistoryDays(tier: SubscriptionTier): number {
  return TIER_HISTORY_DAYS[tier]
}

export function getExportRowLimit(tier: SubscriptionTier): number {
  return TIER_EXPORT_ROWS[tier]
}
