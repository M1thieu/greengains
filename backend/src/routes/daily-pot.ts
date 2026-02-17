import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { getPool } from '../database';
import { requireFirebaseAuth } from '../middleware/auth';

interface DailyPotState {
  user_id: string;
  total_credits: number;
  uploads_today: number;
  uploads_required: number;
  is_unlocked: boolean;
  has_claimed_today: boolean;
  last_claim_date: string | null;
}

interface DailyPotResponse {
  userId: string;
  totalCredits: number;
  uploadsToday: number;
  uploadsRequired: number;
  isUnlocked: boolean;
  hasClaimedToday: boolean;
  lastClaimDate: string | null;
}

function toCamelCase(state: DailyPotState): DailyPotResponse {
  return {
    userId: state.user_id,
    totalCredits: state.total_credits,
    uploadsToday: state.uploads_today,
    uploadsRequired: state.uploads_required,
    isUnlocked: state.is_unlocked,
    hasClaimedToday: state.has_claimed_today,
    lastClaimDate: state.last_claim_date,
  };
}

export async function dailyPotRoutes(fastify: FastifyInstance) {
  const pool = getPool();

  // GET /daily-pot - Get current daily pot state
  fastify.get('/daily-pot', { preHandler: requireFirebaseAuth }, async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const userId = request.user!.uid;

      // Get or create daily pot state
      const result = await pool.query<DailyPotState>(
        `
        INSERT INTO daily_pots (user_id, total_credits, uploads_today, uploads_required, last_claim_date)
        VALUES ($1, 0, 0, 5, NULL)
        ON CONFLICT (user_id) DO UPDATE SET user_id = $1
        RETURNING
          user_id,
          total_credits,
          uploads_today,
          uploads_required,
          CASE
            WHEN uploads_today >= uploads_required THEN true
            ELSE false
          END as is_unlocked,
          CASE
            WHEN last_claim_date = CURRENT_DATE THEN true
            ELSE false
          END as has_claimed_today,
          CASE
            WHEN last_claim_date IS NOT NULL THEN TO_CHAR(last_claim_date, 'YYYY-MM-DD')
            ELSE NULL
          END as last_claim_date
        `,
        [userId]
      );

      return reply.send(toCamelCase(result.rows[0]));
    } catch (error: any) {
      fastify.log.error({ err: error }, 'Error fetching daily pot state');
      return reply.code(500).send({ error: 'Internal server error' });
    }
  });

  // POST /daily-pot/upload - Record successful upload
  fastify.post('/daily-pot/upload', { preHandler: requireFirebaseAuth }, async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const userId = request.user!.uid;

      // Increment upload count with proper daily reset logic
      const result = await pool.query<DailyPotState>(
        `
        INSERT INTO daily_pots (user_id, total_credits, uploads_today, uploads_required, last_claim_date)
        VALUES ($1, 0, 1, 5, NULL)
        ON CONFLICT (user_id) DO UPDATE SET
          uploads_today = CASE
            -- New day since last claim: reset to 1
            WHEN daily_pots.last_claim_date < CURRENT_DATE
            THEN 1
            -- Same day as claim, increment if not yet at required amount
            WHEN daily_pots.last_claim_date = CURRENT_DATE AND daily_pots.uploads_today < daily_pots.uploads_required
            THEN daily_pots.uploads_today + 1
            -- Never claimed before: check if new day since last update
            WHEN daily_pots.last_claim_date IS NULL AND DATE(daily_pots.updated_at) < CURRENT_DATE
            THEN 1
            -- Never claimed and same day: increment
            WHEN daily_pots.last_claim_date IS NULL
            THEN daily_pots.uploads_today + 1
            -- Default: keep current value (shouldn't happen)
            ELSE daily_pots.uploads_today
          END
        RETURNING
          user_id,
          total_credits,
          uploads_today,
          uploads_required,
          CASE
            WHEN uploads_today >= uploads_required THEN true
            ELSE false
          END as is_unlocked,
          CASE
            WHEN last_claim_date = CURRENT_DATE THEN true
            ELSE false
          END as has_claimed_today,
          CASE
            WHEN last_claim_date IS NOT NULL THEN TO_CHAR(last_claim_date, 'YYYY-MM-DD')
            ELSE NULL
          END as last_claim_date
        `,
        [userId]
      );

      return reply.send(toCamelCase(result.rows[0]));
    } catch (error: any) {
      fastify.log.error({ err: error }, 'Error recording upload');
      return reply.code(500).send({ error: 'Internal server error' });
    }
  });

  // POST /daily-pot/claim - Claim the daily pot
  fastify.post('/daily-pot/claim', { preHandler: requireFirebaseAuth }, async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const userId = request.user!.uid;

      // Check if can claim (unlocked and not claimed today)
      const checkResult = await pool.query<DailyPotState>(
        `
        SELECT
          user_id,
          total_credits,
          uploads_today,
          uploads_required,
          CASE
            WHEN uploads_today >= uploads_required THEN true
            ELSE false
          END as is_unlocked,
          CASE
            WHEN last_claim_date = CURRENT_DATE THEN true
            ELSE false
          END as has_claimed_today,
          CASE
            WHEN last_claim_date IS NOT NULL THEN TO_CHAR(last_claim_date, 'YYYY-MM-DD')
            ELSE NULL
          END as last_claim_date
        FROM daily_pots
        WHERE user_id = $1
        `,
        [userId]
      );

      if (checkResult.rows.length === 0) {
        return reply.code(400).send({ error: 'Daily pot not initialized' });
      }

      const state = checkResult.rows[0];

      if (!state.is_unlocked) {
        return reply.code(400).send({ error: 'Daily pot not unlocked yet' });
      }

      if (state.has_claimed_today) {
        return reply.code(409).send({ error: 'Already claimed today' });
      }

      // Generate random reward (10-100 in increments of 5)
      const randomIndex = Math.floor(Math.random() * 19); // 0-18
      const claimedAmount = (randomIndex * 5) + 10; // 10, 15, 20, ..., 100

      // Claim the pot
      const claimResult = await pool.query<DailyPotState & { claimed_amount: number }>(
        `
        UPDATE daily_pots
        SET
          total_credits = total_credits + $2,
          last_claim_date = CURRENT_DATE,
          uploads_today = 0
        WHERE user_id = $1
        RETURNING
          user_id,
          total_credits,
          uploads_today,
          uploads_required,
          CASE
            WHEN uploads_today >= uploads_required THEN true
            ELSE false
          END as is_unlocked,
          CASE
            WHEN last_claim_date = CURRENT_DATE THEN true
            ELSE false
          END as has_claimed_today,
          CASE
            WHEN last_claim_date IS NOT NULL THEN TO_CHAR(last_claim_date, 'YYYY-MM-DD')
            ELSE NULL
          END as last_claim_date,
          $2::integer as claimed_amount
        `,
        [userId, claimedAmount]
      );

      const updatedState = claimResult.rows[0];

      return reply.send({
        ...toCamelCase(updatedState),
        claimedAmount: updatedState.claimed_amount,
      });
    } catch (error: any) {
      fastify.log.error({ err: error }, 'Error claiming daily pot');
      return reply.code(500).send({ error: 'Internal server error' });
    }
  });
}
