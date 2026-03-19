import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { latLngToCell, cellToBoundary, cellToLatLng, cellToParent } from 'h3-js';
import { getPool } from '../database';
import { requireFirebaseAuth } from '../middleware/auth';
import { decodeGeohash } from '../utils/geo';

// Confidence thresholds
const CONFIDENCE_BATCH_THRESHOLD  = 10;  // personal tiles: 10 batches = max confidence
const CONFIDENCE_SAMPLE_THRESHOLD = 100; // global tiles: 100 readings = max confidence

// ─── In-memory cache for global tiles (5-min TTL, avoids per-request DB hits) ─
interface TileCacheEntry { data: unknown; expiresAt: number; }
const _globalTileCache = new Map<string, TileCacheEntry>();
const GLOBAL_TILE_CACHE_TTL_MS = 5 * 60 * 1000;

/**
 * User-specific endpoints (profile, H3 tiles, stats)
 * All endpoints require Firebase authentication
 */
export async function userRoutes(fastify: FastifyInstance) {

  /**
   * GET /api/user/profile
   * Returns user stats aggregated across all their devices
   */
  fastify.get(
    '/api/user/profile',
    { preHandler: requireFirebaseAuth },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.uid;

      try {
        const pool = getPool();

        // Aggregate stats across all user's devices
        const statsResult = await pool.query(
          `SELECT
            COALESCE(SUM(samples_count), 0)::bigint as total_uploads,
            COALESCE(SUM(valid_samples), 0)::bigint as valid_samples,
            COUNT(DISTINCT device_hash) as device_count,
            MIN(created_at) as first_upload_date,
            MAX(last_upload_at) as last_upload_date
          FROM user_stats
          WHERE user_id = $1`,
          [userId]
        );

        if (statsResult.rows.length === 0 || !statsResult.rows[0].total_uploads) {
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
            },
          });
        }

        const row = statsResult.rows[0];

        // Count uploads today
        const todayResult = await pool.query(
          `SELECT COUNT(*)::int as uploads_today
          FROM sensor_batches
          WHERE user_id = $1
          AND DATE(timestamp_utc) = CURRENT_DATE`,
          [userId]
        );
        const uploadsToday = todayResult.rows[0]?.uploads_today || 0;

        // Calculate days active (distinct upload dates)
        const daysActiveResult = await pool.query(
          `SELECT COUNT(DISTINCT DATE(timestamp_utc))::int as days_active
          FROM sensor_batches
          WHERE user_id = $1`,
          [userId]
        );
        const daysActive = daysActiveResult.rows[0]?.days_active || 0;

        // Calculate streaks (consecutive days with uploads)
        const streakResult = await pool.query(
          `WITH daily_uploads AS (
            SELECT DISTINCT DATE(timestamp_utc) as upload_date
            FROM sensor_batches
            WHERE user_id = $1
            ORDER BY upload_date DESC
          ),
          date_diff AS (
            SELECT
              upload_date,
              upload_date - LAG(upload_date, 1, upload_date) OVER (ORDER BY upload_date DESC) as gap
            FROM daily_uploads
          ),
          streak_groups AS (
            SELECT
              upload_date,
              SUM(CASE WHEN gap < -1 THEN 1 ELSE 0 END) OVER (ORDER BY upload_date DESC) as streak_id
            FROM date_diff
          )
          SELECT
            MAX(streak_length) as longest_streak,
            CASE WHEN MIN(upload_date) = CURRENT_DATE THEN current_streak ELSE 0 END as current_streak
          FROM (
            SELECT
              streak_id,
              COUNT(*) as streak_length,
              MIN(upload_date) as min_date,
              MAX(CASE WHEN upload_date >= CURRENT_DATE THEN COUNT(*) ELSE 0 END) as current_streak
            FROM streak_groups
            GROUP BY streak_id
          ) t`,
          [userId]
        );

        const longestStreak = streakResult.rows[0]?.longest_streak || 0;
        const currentStreak = streakResult.rows[0]?.current_streak || 0;

        // Distinct coverage cells (h3_res9 precision — ~174m hexagons)
        const coverageResult = await pool.query(
          `SELECT COUNT(DISTINCT h3_res9)::int as coverage_cells
           FROM sensor_batches
           WHERE user_id = $1 AND h3_res9 IS NOT NULL`,
          [userId]
        );
        const coverageCells = coverageResult.rows[0]?.coverage_cells || 0;

        // 7-day upload history (last 7 days, index 0 = 6 days ago, index 6 = today)
        const weeklyResult = await pool.query(
          `SELECT
            DATE(timestamp_utc) as upload_date,
            COUNT(*)::int as count
          FROM sensor_batches
          WHERE user_id = $1
            AND timestamp_utc >= CURRENT_DATE - INTERVAL '6 days'
          GROUP BY DATE(timestamp_utc)
          ORDER BY upload_date ASC`,
          [userId]
        );

        const weekly: number[] = Array(7).fill(0);
        const todayMidnight = new Date();
        todayMidnight.setUTCHours(0, 0, 0, 0);
        for (const wr of weeklyResult.rows) {
          const d = new Date(wr.upload_date);
          d.setUTCHours(0, 0, 0, 0);
          const daysAgo = Math.round((todayMidnight.getTime() - d.getTime()) / 86400000);
          if (daysAgo >= 0 && daysAgo < 7) weekly[6 - daysAgo] = wr.count;
        }

        return reply.send({
          uid: userId,
          createdAt: row.first_upload_date,
          stats: {
            totalUploads: parseInt(row.total_uploads, 10),
            uploadsToday,
            daysActive,
            currentStreak,
            longestStreak,
            coverageCells,
            deviceCount: parseInt(row.device_count, 10),
            firstUploadDate: row.first_upload_date,
            lastUploadDate: row.last_upload_date,
            weekly,
          },
        });
      } catch (error) {
        request.log.error({ err: error }, 'Profile fetch error');
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    }
  );

  /**
   * GET /api/user/tiles
   * Returns personal H3 coverage tiles (res 9, ~174m edge).
   * Queries sensor_batches directly by h3_res9 column — no JSONB extraction.
   * Query params: ?hours=24 (optional, default 24)
   */
  fastify.get(
    '/api/user/tiles',
    { preHandler: requireFirebaseAuth },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.uid;

      try {
        const pool = getPool();

        // Personal tiles = lifetime map — no time filter.
        // A user's coverage map should show every route they've ever contributed,
        // not just a rolling window. This is how Silencio/Nodle/Helium work.
        // LIMIT 5000 distinct cells is a safe upper bound (a city-scale contributor
        // generates ~2000–3000 cells over years of daily commuting).
        const tilesResult = await pool.query(
          `SELECT
             h3_res9,
             COUNT(*)::int                AS batch_count,
             COUNT(DISTINCT device_hash)::int AS device_count,
             MAX(timestamp_utc)           AS last_update
           FROM sensor_batches
           WHERE user_id = $1
             AND h3_res9 IS NOT NULL
           GROUP BY h3_res9
           ORDER BY batch_count DESC
           LIMIT 5000`,
          [userId],
        );

        const tiles = tilesResult.rows.map(row => {
          const h3Index = row.h3_res9 as string;
          // cellToBoundary(h3, true) → [lng, lat][] GeoJSON order, ring auto-closed
          const boundary = cellToBoundary(h3Index, true) as [number, number][];
          const [lat, lng] = cellToLatLng(h3Index);
          return {
            h3Index,
            boundary,
            centroid: { lat, lng },
            confidence: Math.min(1.0, row.batch_count / CONFIDENCE_BATCH_THRESHOLD),
            sampleCount: row.batch_count,
            deviceCount: row.device_count,
            lastUpdate: row.last_update,
          };
        });

        return reply.send({ tiles });
      } catch (error) {
        request.log.error({ err: error }, 'Tiles fetch error');
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    }
  );

  /**
   * GET /api/tiles/global
   * Returns global H3 coverage tiles (res 8, ~461m edge) from all users.
   * Queries sensor_aggregates_5m (pre-computed) — not raw sensor_batches.
   * Uses h3_index column when available; falls back to geohash decode for old rows.
   * Results cached 5 min in-memory.
   * Query params: ?hours=48 (optional, default 48)
   */
  fastify.get(
    '/api/tiles/global',
    { preHandler: requireFirebaseAuth },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        // Global tiles: 30-day window — community coverage should feel populated.
        const hours = 720;
        const cacheKey = `global_${hours}`;

        const cached = _globalTileCache.get(cacheKey);
        if (cached && cached.expiresAt > Date.now()) {
          return reply.send(cached.data);
        }

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
          [hours],
        );

        const seenGlobal = new Set<string>();
        const tiles = result.rows
          .map(row => {
            // Prefer pre-computed h3_index; fall back to geohash decode for old rows
            let h3Res9: string | null = row.h3_index;
            if (!h3Res9) {
              const centroid = decodeGeohash(row.geohash);
              if (!centroid) return null;
              h3Res9 = latLngToCell(centroid.lat, centroid.lon, 9);
            }
            // Coarsen to res 8 for global view (neighbourhood scale)
            const h3Index = cellToParent(h3Res9, 8);
            if (seenGlobal.has(h3Index)) return null;
            seenGlobal.add(h3Index);
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

        return reply.send(data);
      } catch (error) {
        request.log.error({ err: error }, 'Global tiles fetch error');
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    },
  );

  /**
   * GET /api/tiles/public
   * Unauthenticated global coverage tiles — same data as /api/tiles/global,
   * shares the same 5-min in-memory cache. Used by the public coverage explorer.
   */
  fastify.get(
    '/api/tiles/public',
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const hours = 720; // 30-day window — community coverage should feel populated
        const cacheKey = `global_${hours}`;

        const cached = _globalTileCache.get(cacheKey);
        if (cached && cached.expiresAt > Date.now()) {
          return reply.send(cached.data);
        }

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
          [hours],
        );

        const seenGlobal = new Set<string>();
        const tiles = result.rows
          .map(row => {
            let h3Res9: string | null = row.h3_index;
            if (!h3Res9) {
              const centroid = decodeGeohash(row.geohash);
              if (!centroid) return null;
              h3Res9 = latLngToCell(centroid.lat, centroid.lon, 9);
            }
            const h3Index = cellToParent(h3Res9, 8);
            if (seenGlobal.has(h3Index)) return null;
            seenGlobal.add(h3Index);
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

        return reply.send(data);
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
        const { platform, appVersion } = (request.body as any) ?? {};
        const pool = getPool();

        await pool.query(
          `INSERT INTO user_consent_agreements (user_id, platform, app_version)
           VALUES ($1, $2, $3)`,
          [userId, platform ?? null, appVersion ?? null]
        );

        const row = await pool.query(
          `SELECT agreed_at FROM user_consent_agreements
           WHERE user_id = $1
           ORDER BY agreed_at DESC LIMIT 1`,
          [userId]
        );

        return reply.send({ agreedAt: row.rows[0].agreed_at });
      } catch (error) {
        request.log.error({ err: error }, 'Consent record error');
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    }
  );
}
