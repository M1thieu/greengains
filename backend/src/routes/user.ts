import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { latLngToCell, cellToBoundary, cellToLatLng, cellToParent } from 'h3-js';
import { getPool } from '../database';
import { requireFirebaseAuth } from '../middleware/auth';
import { decodeGeohash } from '../utils/geo';

// Confidence thresholds
const CONFIDENCE_BATCH_THRESHOLD  = 10;  // personal tiles: 10 batches = max confidence
const CONFIDENCE_SAMPLE_THRESHOLD = 100; // global tiles: 100 readings = max confidence

// Global tiles: 30-day window — community coverage should feel populated.
const GLOBAL_TILE_HOURS = 720;

// ─── In-memory cache for global tiles (5-min TTL, avoids per-request DB hits) ─
interface TileCacheEntry { data: unknown; expiresAt: number; }
const _globalTileCache = new Map<string, TileCacheEntry>();
const GLOBAL_TILE_CACHE_TTL_MS = 5 * 60 * 1000;

// ─── Shared global tile query ─────────────────────────────────────────────────

/**
 * Fetches global community tiles from sensor_aggregates_5m.
 * Results are cached 5 min in-memory (shared between /global and /public).
 * Falls back to geohash decode for rows without h3_index.
 */
async function fetchGlobalTiles(): Promise<unknown> {
  const cacheKey = `global_${GLOBAL_TILE_HOURS}`;
  const cached = _globalTileCache.get(cacheKey);
  if (cached && cached.expiresAt > Date.now()) return cached.data;

  const pool = getPool();
  const result = await pool.query<{
    geohash: string;
    h3_index: string | null;
    sample_count: number;
    device_count: number;
    last_update: Date;
  }>(
    `SELECT
       geohash,
       h3_index,
       SUM(samples_count)::int AS sample_count,
       SUM(device_count)::int  AS device_count,
       MAX(window_end)         AS last_update
     FROM sensor_aggregates_5m
     WHERE window_start > NOW() - ($1 || ' hours')::interval
     GROUP BY geohash, h3_index
     ORDER BY sample_count DESC
     LIMIT 2000`,
    [GLOBAL_TILE_HOURS],
  );

  const seen = new Set<string>();
  const tiles = result.rows
    .map(row => {
      let h3Res9: string | null = row.h3_index;
      if (!h3Res9) {
        const centroid = decodeGeohash(row.geohash);
        if (!centroid) return null;
        h3Res9 = latLngToCell(centroid.lat, centroid.lon, 9);
      }
      const h3Index = cellToParent(h3Res9, 8); // coarsen to res 8 for global view
      if (seen.has(h3Index)) return null;
      seen.add(h3Index);
      const boundary = cellToBoundary(h3Index, true) as [number, number][];
      return {
        h3Index,
        boundary,
        confidence: Math.min(1.0, row.sample_count / CONFIDENCE_SAMPLE_THRESHOLD),
        deviceCount: row.device_count,
        sampleCount: row.sample_count,
        lastUpdate: row.last_update,
      };
    })
    .filter(Boolean);

  const data = { tiles };
  _globalTileCache.set(cacheKey, { data, expiresAt: Date.now() + GLOBAL_TILE_CACHE_TTL_MS });
  return data;
}

/**
 * User-specific endpoints (profile, H3 tiles, stats)
 * All endpoints require Firebase authentication
 */
export async function userRoutes(fastify: FastifyInstance) {

  /**
   * GET /api/user/profile
   * Returns user stats aggregated across all their devices.
   * Runs 2 queries: one CTE for all scalar stats, one for 7-day weekly breakdown.
   */
  fastify.get(
    '/api/user/profile',
    { preHandler: requireFirebaseAuth },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.uid;

      try {
        const pool = getPool();

        // Single query for all scalar stats — avoids 5 round-trips.
        // Queries sensor_batches directly (source of truth for user_id attribution;
        // user_stats.user_id can be stale if device was reinstalled).
        const statsResult = await pool.query<{
          total_batches: number;
          uploads_today: number;
          days_active: number;
          device_count: number;
          coverage_cells: number;
          first_upload_date: Date | null;
          last_upload_date: Date | null;
        }>(
          `SELECT
             COUNT(*)::int                                                 AS total_batches,
             COUNT(*) FILTER (WHERE DATE(timestamp_utc) = CURRENT_DATE)::int AS uploads_today,
             COUNT(DISTINCT DATE(timestamp_utc))::int                     AS days_active,
             COUNT(DISTINCT device_hash)::int                             AS device_count,
             COUNT(DISTINCT h3_res9) FILTER (WHERE h3_res9 IS NOT NULL)::int AS coverage_cells,
             MIN(timestamp_utc)                                           AS first_upload_date,
             MAX(timestamp_utc)                                           AS last_upload_date
           FROM sensor_batches
           WHERE user_id = $1`,
          [userId],
        );

        const row = statsResult.rows[0];

        if (!row || row.total_batches === 0) {
          return reply.send({
            uid: userId,
            stats: {
              totalUploads: 0,
              uploadsToday: 0,
              daysActive: 0,
              currentStreak: 0,
              longestStreak: 0,
              coverageCells: 0,
              deviceCount: 0,
              firstUploadDate: null,
              lastUploadDate: null,
              weekly: Array(7).fill(0),
            },
          });
        }

        // Streak calculation — gaps-and-islands algorithm (no nested aggregates).
        // Groups consecutive upload dates by subtracting their row number from the
        // date: consecutive dates produce the same value → same group.
        // Current streak = length of the latest group, but only if it includes
        // today or yesterday (grace period so streak survives through the day).
        const streakResult = await pool.query<{
          longest_streak: number;
          current_streak: number;
        }>(
          `WITH daily AS (
             SELECT DISTINCT DATE(timestamp_utc) AS d
             FROM sensor_batches
             WHERE user_id = $1
           ),
           numbered AS (
             SELECT d, ROW_NUMBER() OVER (ORDER BY d DESC)::int AS rn
             FROM daily
           ),
           groups AS (
             SELECT (d + rn) AS grp, COUNT(*)::int AS len, MAX(d) AS latest_day
             FROM numbered
             GROUP BY grp
           )
           SELECT
             MAX(len)                                              AS longest_streak,
             COALESCE(
               (SELECT len FROM groups
                WHERE latest_day >= CURRENT_DATE - 1
                ORDER BY latest_day DESC LIMIT 1),
               0
             )                                                     AS current_streak
           FROM groups`,
          [userId],
        );

        const longestStreak = streakResult.rows[0]?.longest_streak ?? 0;
        const currentStreak = streakResult.rows[0]?.current_streak ?? 0;

        // 7-day upload history (index 0 = 6 days ago, index 6 = today)
        const weeklyResult = await pool.query<{
          upload_date: Date;
          count: number;
        }>(
          `SELECT
             DATE(timestamp_utc) AS upload_date,
             COUNT(*)::int       AS count
           FROM sensor_batches
           WHERE user_id = $1
             AND timestamp_utc >= CURRENT_DATE - INTERVAL '6 days'
           GROUP BY DATE(timestamp_utc)
           ORDER BY upload_date ASC`,
          [userId],
        );

        const weekly: number[] = Array(7).fill(0);
        const todayMs = Date.UTC(
          new Date().getUTCFullYear(),
          new Date().getUTCMonth(),
          new Date().getUTCDate(),
        );
        for (const wr of weeklyResult.rows) {
          const d = new Date(wr.upload_date);
          const daysAgo = Math.round((todayMs - d.getTime()) / 86_400_000);
          if (daysAgo >= 0 && daysAgo < 7) weekly[6 - daysAgo] = wr.count;
        }

        return reply.send({
          uid: userId,
          createdAt: row.first_upload_date,
          stats: {
            totalUploads: row.total_batches,
            uploadsToday: row.uploads_today,
            daysActive: row.days_active,
            currentStreak,
            longestStreak,
            coverageCells: row.coverage_cells,
            deviceCount: row.device_count,
            firstUploadDate: row.first_upload_date,
            lastUploadDate: row.last_upload_date,
            weekly,
          },
        });
      } catch (error) {
        request.log.error({ err: error }, 'Profile fetch error');
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    },
  );

  /**
   * GET /api/user/tiles
   * Returns personal H3 coverage tiles (res 9, ~174m edge).
   * Includes geohash fallback for rows uploaded before the h3_res9 migration.
   */
  fastify.get(
    '/api/user/tiles',
    { preHandler: requireFirebaseAuth },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.uid;

      try {
        const pool = getPool();

        // Include rows with h3_res9 OR a geohash fallback — handles pre-migration data.
        const tilesResult = await pool.query<{
          h3_res9: string | null;
          geohash: string | null;
          batch_count: number;
          device_count: number;
          last_update: Date;
        }>(
          `SELECT
             h3_res9,
             batch_json->>'geohash'           AS geohash,
             COUNT(*)::int                    AS batch_count,
             COUNT(DISTINCT device_hash)::int AS device_count,
             MAX(timestamp_utc)               AS last_update
           FROM sensor_batches
           WHERE user_id = $1
             AND (h3_res9 IS NOT NULL OR batch_json->>'geohash' IS NOT NULL)
           GROUP BY h3_res9, batch_json->>'geohash'
           ORDER BY batch_count DESC
           LIMIT 5000`,
          [userId],
        );

        // Resolve each row to a final h3 cell. Rows mapping to the same cell are merged.
        const tileMap = new Map<string, { batchCount: number; deviceCount: number; lastUpdate: Date }>();
        for (const row of tilesResult.rows) {
          let h3Index: string | null = row.h3_res9;
          if (!h3Index && row.geohash) {
            const centroid = decodeGeohash(row.geohash);
            if (!centroid) continue;
            h3Index = latLngToCell(centroid.lat, centroid.lon, 9);
          }
          if (!h3Index) continue;
          const existing = tileMap.get(h3Index);
          if (existing) {
            existing.batchCount += row.batch_count;
            existing.deviceCount = Math.max(existing.deviceCount, row.device_count);
            if (row.last_update > existing.lastUpdate) existing.lastUpdate = row.last_update;
          } else {
            tileMap.set(h3Index, { batchCount: row.batch_count, deviceCount: row.device_count, lastUpdate: row.last_update });
          }
        }

        const tiles = Array.from(tileMap.entries())
          .sort((a, b) => b[1].batchCount - a[1].batchCount)
          .slice(0, 5000)
          .map(([h3Index, stats]) => {
            const boundary = cellToBoundary(h3Index, true) as [number, number][];
            const [lat, lng] = cellToLatLng(h3Index);
            return {
              h3Index,
              boundary,
              centroid: { lat, lng },
              confidence: Math.min(1.0, stats.batchCount / CONFIDENCE_BATCH_THRESHOLD),
              sampleCount: stats.batchCount,
              deviceCount: stats.deviceCount,
              lastUpdate: stats.lastUpdate,
            };
          });

        request.log.info({ tileCount: tiles.length, userId }, 'User tiles fetched');
        return reply.send({ tiles });
      } catch (error) {
        request.log.error({ err: error }, 'Tiles fetch error');
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    },
  );

  /**
   * GET /api/tiles/global
   * Global H3 coverage tiles (res 8). Requires auth. Cached 5 min.
   */
  fastify.get(
    '/api/tiles/global',
    { preHandler: requireFirebaseAuth },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        return reply.send(await fetchGlobalTiles());
      } catch (error) {
        request.log.error({ err: error }, 'Global tiles fetch error');
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    },
  );

  /**
   * GET /api/tiles/public
   * Unauthenticated global coverage tiles — same data as /global, shares cache.
   */
  fastify.get(
    '/api/tiles/public',
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        return reply.send(await fetchGlobalTiles());
      } catch (error) {
        request.log.error({ err: error }, 'Public tiles fetch error');
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    },
  );

  /**
   * POST /api/user/consent
   * Records that the authenticated user explicitly accepted the privacy policy.
   * Body: { platform?: 'android'|'ios', appVersion?: string }
   * Returns: { agreedAt: ISO timestamp }
   */
  fastify.post(
    '/api/user/consent',
    { preHandler: requireFirebaseAuth },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.uid;

      try {
        const body = (request.body ?? {}) as { platform?: string; appVersion?: string };
        const { platform, appVersion } = body;
        const pool = getPool();

        await pool.query(
          `INSERT INTO user_consent_agreements (user_id, platform, app_version)
           VALUES ($1, $2, $3)`,
          [userId, platform ?? null, appVersion ?? null],
        );

        const row = await pool.query(
          `SELECT agreed_at FROM user_consent_agreements
           WHERE user_id = $1
           ORDER BY agreed_at DESC LIMIT 1`,
          [userId],
        );

        return reply.send({ agreedAt: row.rows[0].agreed_at });
      } catch (error) {
        request.log.error({ err: error }, 'Consent record error');
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    },
  );
}
