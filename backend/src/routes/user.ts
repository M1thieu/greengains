import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { getPool } from '../database';
import { requireFirebaseAuth } from '../middleware/auth';

// Constants for tile grouping (temporary until H3 implementation)
const TILE_PRECISION_DECIMALS = 3; // ~100m precision at mid-latitudes
const CONFIDENCE_SAMPLE_THRESHOLD = 100; // Samples needed for max confidence

// ─── Geohash decoder (no extra dependency) ────────────────────────────────────
const GH_BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

function decodeGeohash(hash: string): { lat: number; lon: number } | null {
  if (!hash || hash.length === 0) return null;
  let isLon = true;
  const lat = [-90.0, 90.0];
  const lon = [-180.0, 180.0];
  for (const ch of hash) {
    const idx = GH_BASE32.indexOf(ch);
    if (idx === -1) return null;
    for (let bit = 4; bit >= 0; bit--) {
      const bitN = (idx >> bit) & 1;
      if (isLon) {
        const mid = (lon[0] + lon[1]) / 2;
        if (bitN) lon[0] = mid; else lon[1] = mid;
      } else {
        const mid = (lat[0] + lat[1]) / 2;
        if (bitN) lat[0] = mid; else lat[1] = mid;
      }
      isLon = !isLon;
    }
  }
  return { lat: (lat[0] + lat[1]) / 2, lon: (lon[0] + lon[1]) / 2 };
}

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
              areaCovered: 0.0,
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
   * Returns H3 tiles with boundaries for coverage map
   * Query params: ?hours=24 (optional, default 24)
   */
  fastify.get(
    '/api/user/tiles',
    { preHandler: requireFirebaseAuth },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.uid;

      try {
        const { hours = 24 } = request.query as { hours?: number };
        const pool = getPool();

        // Extract location data and group by approximate location
        // Temporary grouping until H3 implementation
        const tilesResult = await pool.query(
          `SELECT
            ROUND((batch_json->'location'->>'lat')::numeric, $3) as lat,
            ROUND((batch_json->'location'->>'lon')::numeric, $3) as lon,
            AVG((batch_json->'location'->>'accuracy_m')::float) as avg_accuracy_m,
            COUNT(*) as sample_count,
            MAX(timestamp_utc) as last_update,
            AVG((batch_json->'summary'->'light'->>'avg')::float) as avg_light,
            AVG((batch_json->'summary'->>'accel_rms')::float) as avg_accel_rms
          FROM sensor_batches
          WHERE user_id = $1
          AND timestamp_utc > NOW() - ($2 || ' hours')::interval
          AND batch_json->'location' IS NOT NULL
          GROUP BY ROUND((batch_json->'location'->>'lat')::numeric, $3),
                   ROUND((batch_json->'location'->>'lon')::numeric, $3)
          ORDER BY last_update DESC`,
          [userId, hours, TILE_PRECISION_DECIMALS]
        );

        // Transform to tile format
        // Generate simple tile ID from rounded lat/lon until we add h3-js library
        const tiles = tilesResult.rows.map(row => ({
          h3Index: `tile_${row.lat}_${row.lon}`, // Temporary tile ID
          centroid: {
            lat: parseFloat(row.lat),
            lng: parseFloat(row.lon),
          },
          confidence: Math.min(1.0, (parseInt(row.sample_count, 10) / CONFIDENCE_SAMPLE_THRESHOLD)),
          sampleCount: parseInt(row.sample_count, 10),
          deviceCount: 1,
          lastUpdate: row.last_update,
          avgLight: row.avg_light ? parseFloat(row.avg_light) : null,
          avgAccelRms: row.avg_accel_rms ? parseFloat(row.avg_accel_rms) : null,
        }));

        return reply.send({ tiles });
      } catch (error) {
        request.log.error({ err: error }, 'Tiles fetch error');
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    }
  );

  /**
   * GET /api/tiles/global
   * Returns aggregated coverage tiles from all users (community map).
   * Results are cached in-memory for 5 minutes to keep DB load minimal.
   * Query params: ?hours=48 (optional, default 48)
   */
  fastify.get(
    '/api/tiles/global',
    { preHandler: requireFirebaseAuth },
    async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const { hours = 48 } = request.query as { hours?: number };
        const cacheKey = `global_${hours}`;

        // Serve from cache if still fresh
        const cached = _globalTileCache.get(cacheKey);
        if (cached && cached.expiresAt > Date.now()) {
          return reply.send(cached.data);
        }

        const pool = getPool();

        const result = await pool.query<{
          geohash: string;
          device_count: number;
          sample_count: number;
          last_update: Date;
        }>(
          `SELECT
             batch_json->>'geohash' AS geohash,
             COUNT(DISTINCT device_hash)::int AS device_count,
             COUNT(*)::int AS sample_count,
             MAX(timestamp_utc) AS last_update
           FROM sensor_batches
           WHERE batch_json->>'geohash' IS NOT NULL
             AND timestamp_utc > NOW() - ($1 || ' hours')::interval
           GROUP BY batch_json->>'geohash'
           ORDER BY sample_count DESC
           LIMIT 2000`,
          [hours],
        );

        const tiles = result.rows
          .map(row => {
            const centroid = decodeGeohash(row.geohash);
            if (!centroid) return null;
            return {
              h3Index: row.geohash,
              centroid,
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
