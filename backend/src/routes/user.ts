import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import { latLngToCell, cellToBoundary, cellToLatLng, cellToParent } from 'h3-js';
import { getPool } from '../database';
import { requireFirebaseAuth } from '../middleware/auth';
import { decodeGeohash } from '../utils/geo';
import {
  H3_RES_GLOBAL,
  MAX_USER_TILES,
  MAX_GLOBAL_TILES,
  GLOBAL_TILE_WINDOW_HOURS,
  MS_PER_DAY,
  MAX_TILE_RESPONSE_BYTES,
  CONFIDENCE_BATCH_THRESHOLD,
  CONFIDENCE_SAMPLE_THRESHOLD,
  GLOBAL_TILE_CACHE_TTL_MS,
  GLOBAL_TILE_CACHE_TTL_S,
} from '../constants';

// ─── In-memory cache for global tiles (5-min TTL, avoids per-request DB hits) ─
interface TileCacheEntry { data: unknown; expiresAt: number; }
const _globalTileCache = new Map<string, TileCacheEntry>();

// ─── In-memory cache for global stats (1-hour TTL) ───────────────────────────
interface StatsCacheEntry { data: { activeMappers: number; totalZones: number }; expiresAt: number; }
let _globalStatsCache: StatsCacheEntry | null = null;

// ─── Per-user profile cache (60s TTL) ────────────────────────────────────────
// Eliminates repeated DB hits on every stats screen open / app resume.
// Invalidated on upload (via invalidateProfileCache) so fresh data appears
// within one minute after a user uploads — acceptable staleness for a stats view.
const USER_PROFILE_CACHE_TTL_MS = 60_000;
interface ProfileCacheEntry { data: unknown; expiresAt: number; }
const _profileCache = new Map<string, ProfileCacheEntry>();

/** Call after a successful upload to ensure next profile fetch is fresh. */
export function invalidateProfileCache(userId: string): void {
  _profileCache.delete(userId);
}

/**
 * Refreshes user_profile_cache for the given user after an upload.
 * Runs the same 3 aggregate queries as the profile endpoint, but only on the
 * write path (infrequent) — reads then hit the cache row instead.
 * Fire-and-forget: called without await so the upload response isn't delayed.
 */
export async function refreshUserProfileCache(userId: string): Promise<void> {
  try {
    const pool = getPool();
    // Single query: all scalar stats + streak in one pass using CTEs.
    // Indexes idx_sb_user_h3 + idx_sb_user_date (added in 20260416 migration) make this fast.
    await pool.query(
      `WITH base AS (
         SELECT timestamp_utc, h3_res9
         FROM sensor_batches
         WHERE user_id = $1
       ),
       scalar AS (
         SELECT
           COUNT(*)::int                                                  AS total_batches,
           COUNT(DISTINCT h3_res9) FILTER (WHERE h3_res9 IS NOT NULL)::int AS coverage_cells,
           COUNT(DISTINCT DATE(timestamp_utc))::int                      AS days_active,
           MIN(timestamp_utc)                                            AS first_upload_at,
           MAX(timestamp_utc)                                            AS last_upload_at
         FROM base
       ),
       daily AS (
         SELECT DISTINCT DATE(timestamp_utc) AS d
         FROM base
       ),
       numbered AS (
         SELECT d, ROW_NUMBER() OVER (ORDER BY d DESC)::int AS rn FROM daily
       ),
       groups AS (
         SELECT (d + rn) AS grp, COUNT(*)::int AS len, MAX(d) AS latest_day
         FROM numbered GROUP BY grp
       ),
       streak AS (
         SELECT
           MAX(len) AS longest_streak,
           COALESCE(
             (SELECT len FROM groups WHERE latest_day >= CURRENT_DATE - 1
              ORDER BY latest_day DESC LIMIT 1), 0
           ) AS current_streak
         FROM groups
       )
       INSERT INTO user_profile_cache (
         user_id, total_batches, coverage_cells, days_active,
         current_streak, longest_streak, first_upload_at, last_upload_at, updated_at
       )
       SELECT
         $1,
         s.total_batches, s.coverage_cells, s.days_active,
         k.current_streak, k.longest_streak,
         s.first_upload_at, s.last_upload_at,
         NOW()
       FROM scalar s, streak k
       ON CONFLICT (user_id) DO UPDATE SET
         total_batches   = EXCLUDED.total_batches,
         coverage_cells  = EXCLUDED.coverage_cells,
         days_active     = EXCLUDED.days_active,
         current_streak  = EXCLUDED.current_streak,
         longest_streak  = EXCLUDED.longest_streak,
         first_upload_at = EXCLUDED.first_upload_at,
         last_upload_at  = EXCLUDED.last_upload_at,
         updated_at      = EXCLUDED.updated_at`,
      [userId],
    );
  } catch (err) {
    // Non-fatal — profile endpoint falls back to live queries if cache is missing.
    console.error('[refreshUserProfileCache] failed:', err);
  }
}

// ─── Shared global tile query ─────────────────────────────────────────────────

/**
 * Fetches global community tiles from sensor_aggregates_daily.
 * Uses the daily table for the 30-day window — 288x fewer rows than 5m table,
 * same data quality for a coverage map. Results are cached 5 min in-memory.
 * Falls back to geohash decode for rows without h3_index.
 */
async function fetchGlobalTiles(): Promise<unknown> {
  const cacheKey = `global_${GLOBAL_TILE_WINDOW_HOURS}`;
  const cached = _globalTileCache.get(cacheKey);
  if (cached && cached.expiresAt > Date.now()) return cached.data;

  const pool = getPool();
  // Daily table has ≤30 rows per geohash vs 8,640 rows in 5m table for 30d window.
  // MAX(h3_index) picks the non-null value when both null and non-null rows exist.
  const windowDays = Math.ceil(GLOBAL_TILE_WINDOW_HOURS / 24);
  const result = await pool.query<{
    geohash: string;
    sample_count: number;
    device_count: number;
    quality_valid_ratio: number | null;
    last_update: Date;
  }>(
    `SELECT
       geohash,
       SUM(samples_count)::int                AS sample_count,
       MAX(device_count)::int                 AS device_count,
       AVG(quality_valid_ratio)               AS quality_valid_ratio,
       MAX(day)                               AS last_update
     FROM sensor_aggregates_daily
     WHERE day > CURRENT_DATE - ($1 * INTERVAL '1 day')
     GROUP BY geohash
     ORDER BY sample_count DESC
     LIMIT ${MAX_GLOBAL_TILES}`,
    [windowDays],
  );

  const seen = new Set<string>();
  const tiles = result.rows
    .map(row => {
      const centroid = decodeGeohash(row.geohash);
      if (!centroid) return null;
      let h3Res9: string = latLngToCell(centroid.lat, centroid.lon, 9);
      const h3Index = cellToParent(h3Res9, H3_RES_GLOBAL);
      if (seen.has(h3Index)) return null;
      seen.add(h3Index);
      const boundary = cellToBoundary(h3Index, true) as [number, number][];
      // Composite quality score: blend sample confidence + data validity ratio.
      // qualityValidRatio=1.0 means all readings passed quality checks (not pocket, not noise).
      const sampleConfidence = Math.min(1.0, row.sample_count / CONFIDENCE_SAMPLE_THRESHOLD);
      const qualityValidRatio = row.quality_valid_ratio ?? 1.0;
      const qualityScore = Math.round(sampleConfidence * qualityValidRatio * 100) / 100;
      return {
        h3Index,
        boundary,
        confidence: sampleConfidence,
        qualityScore,
        deviceCount: row.device_count,
        sampleCount: row.sample_count,
        lastUpdate: row.last_update,
      };
    })
    .filter(Boolean);

  const data = { tiles };
  _globalTileCache.set(cacheKey, { data, expiresAt: Date.now() + GLOBAL_TILE_CACHE_TTL_MS });

  // Response size guard: truncate tiles if JSON exceeds limit
  const jsonString = JSON.stringify(data);
  if (Buffer.byteLength(jsonString, 'utf8') > MAX_TILE_RESPONSE_BYTES) {
    const truncatedTiles = tiles.slice(0, Math.floor(tiles.length * 0.8)); // rough 20% reduction
    const truncatedData = { tiles: truncatedTiles };
    console.warn(`[fetchGlobalTiles] Response size exceeded ${MAX_TILE_RESPONSE_BYTES} bytes, truncated to ${truncatedTiles.length} tiles`);
    return truncatedData;
  }

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

      // Serve from in-memory cache when fresh (60s TTL).
      const cached = _profileCache.get(userId);
      if (cached && cached.expiresAt > Date.now()) {
        return reply.send(cached.data);
      }

      try {
        const pool = getPool();

        // Try user_profile_cache first — single PK lookup, ~0.1ms.
        // Falls through to live sensor_batches queries if row is missing
        // (first-ever load before any upload has occurred).
        const cacheRow = await pool.query<{
          total_batches: number;
          coverage_cells: number;
          days_active: number;
          current_streak: number;
          longest_streak: number;
          first_upload_at: Date | null;
          last_upload_at: Date | null;
        }>(
          `SELECT total_batches, coverage_cells, days_active,
                  current_streak, longest_streak,
                  first_upload_at, last_upload_at
           FROM user_profile_cache
           WHERE user_id = $1`,
          [userId],
        );

        // uploads_today always comes from sensor_batches — not cached (changes intraday).
        // device_count also live — rarely needed and fast with existing index.
        const [liveResult, weeklyResult, qualityResult] = await Promise.all([
          pool.query<{ uploads_today: number; device_count: number }>(
            `SELECT
               COUNT(*) FILTER (WHERE DATE(timestamp_utc) = CURRENT_DATE)::int AS uploads_today,
               COUNT(DISTINCT device_hash)::int                                AS device_count
             FROM sensor_batches
             WHERE user_id = $1`,
            [userId],
          ),
          pool.query<{ upload_date: Date; count: number }>(
            `SELECT DATE(timestamp_utc) AS upload_date, COUNT(*)::int AS count
             FROM sensor_batches
             WHERE user_id = $1
               AND timestamp_utc >= CURRENT_DATE - INTERVAL '6 days'
             GROUP BY DATE(timestamp_utc)
             ORDER BY upload_date ASC`,
            [userId],
          ),
          pool.query<{ valid_samples: number; samples_count: number }>(
            `SELECT
               COALESCE(SUM(valid_samples), 0)::int  AS valid_samples,
               COALESCE(SUM(samples_count), 0)::int  AS samples_count
             FROM user_stats
             WHERE user_id = $1`,
            [userId],
          ),
        ]);

        const qr = qualityResult.rows[0];
        const qualityPct = (qr?.samples_count ?? 0) > 0
          ? Math.round((qr.valid_samples / qr.samples_count) * 100)
          : null;

        const weekly: number[] = Array(7).fill(0);
        const todayMs = Date.UTC(
          new Date().getUTCFullYear(),
          new Date().getUTCMonth(),
          new Date().getUTCDate(),
        );
        for (const wr of weeklyResult.rows) {
          const d = new Date(wr.upload_date);
          const daysAgo = Math.round((todayMs - d.getTime()) / MS_PER_DAY);
          if (daysAgo >= 0 && daysAgo < 7) weekly[6 - daysAgo] = wr.count;
        }

        const live = liveResult.rows[0];

        // No cache row AND no live uploads — new user.
        if (!cacheRow.rows[0] && (live?.uploads_today ?? 0) === 0 && weekly.every(v => v === 0)) {
          const emptyData = {
            uid: userId,
            stats: {
              totalUploads: 0, uploadsToday: 0, daysActive: 0,
              currentStreak: 0, longestStreak: 0, coverageCells: 0,
              deviceCount: 0, firstUploadDate: null, lastUploadDate: null,
              weekly: Array(7).fill(0),
            },
          };
          return reply.send(emptyData);
        }

        // If no cache row yet, fall back to full live query for scalar stats.
        let totalUploads: number;
        let coverageCells: number;
        let daysActive: number;
        let currentStreak: number;
        let longestStreak: number;
        let firstUploadDate: Date | null;
        let lastUploadDate: Date | null;

        if (cacheRow.rows[0]) {
          const c = cacheRow.rows[0];
          totalUploads   = c.total_batches;
          coverageCells  = c.coverage_cells;
          daysActive     = c.days_active;
          currentStreak  = c.current_streak;
          longestStreak  = c.longest_streak;
          firstUploadDate = c.first_upload_at;
          lastUploadDate  = c.last_upload_at;
        } else {
          // Cache miss — single CTE scans sensor_batches once for both scalar
          // aggregates and streak computation (previously 2 parallel queries).
          const missResult = await pool.query<{
            total_batches: number; days_active: number; coverage_cells: number;
            first_upload_date: Date | null; last_upload_date: Date | null;
            longest_streak: number; current_streak: number;
          }>(
            `WITH base AS (
               SELECT timestamp_utc, h3_res9
               FROM sensor_batches
               WHERE user_id = $1
             ),
             scalars AS (
               SELECT
                 COUNT(*)::int                                                    AS total_batches,
                 COUNT(DISTINCT DATE(timestamp_utc))::int                        AS days_active,
                 COUNT(DISTINCT h3_res9) FILTER (WHERE h3_res9 IS NOT NULL)::int AS coverage_cells,
                 MIN(timestamp_utc)                                              AS first_upload_date,
                 MAX(timestamp_utc)                                              AS last_upload_date
               FROM base
             ),
             daily AS (SELECT DISTINCT DATE(timestamp_utc) AS d FROM base),
             numbered AS (SELECT d, ROW_NUMBER() OVER (ORDER BY d DESC)::int AS rn FROM daily),
             groups AS (SELECT (d + rn) AS grp, COUNT(*)::int AS len, MAX(d) AS latest_day FROM numbered GROUP BY grp)
             SELECT
               s.*,
               COALESCE((SELECT MAX(len) FROM groups), 0) AS longest_streak,
               COALESCE(
                 (SELECT len FROM groups WHERE latest_day >= CURRENT_DATE - 1 ORDER BY latest_day DESC LIMIT 1),
                 0
               ) AS current_streak
             FROM scalars s`,
            [userId],
          );
          const m = missResult.rows[0];
          totalUploads    = m?.total_batches   ?? 0;
          coverageCells   = m?.coverage_cells  ?? 0;
          daysActive      = m?.days_active     ?? 0;
          currentStreak   = m?.current_streak  ?? 0;
          longestStreak   = m?.longest_streak  ?? 0;
          firstUploadDate = m?.first_upload_date ?? null;
          lastUploadDate  = m?.last_upload_date  ?? null;
        }

        const profileData = {
          uid: userId,
          createdAt: firstUploadDate,
          stats: {
            totalUploads,
            uploadsToday:   live?.uploads_today ?? 0,
            daysActive,
            currentStreak,
            longestStreak,
            coverageCells,
            deviceCount:    live?.device_count ?? 0,
            firstUploadDate,
            lastUploadDate,
            weekly,
            qualityPct,
          },
        };
        _profileCache.set(userId, { data: profileData, expiresAt: Date.now() + USER_PROFILE_CACHE_TTL_MS });
        return reply.send(profileData);
      } catch (error) {
        request.log.error({ err: error, userId }, 'Profile fetch error');
        return reply.code(500).send({ error: 'Internal Server Error', requestId: request.id });
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
          avg_lux: number | null;
          avg_hpa: number | null;
          avg_movement: number | null;
        }>(
          `SELECT
             h3_res9,
             batch_json->>'geohash'                                            AS geohash,
             COUNT(*)::int                                                      AS batch_count,
             COUNT(DISTINCT device_hash)::int                                   AS device_count,
             MAX(timestamp_utc)                                                 AS last_update,
             AVG((batch_json->'summary'->'light'->>'avg')::numeric)             AS avg_lux,
             AVG((batch_json->'summary'->'pressure'->>'avg')::numeric)          AS avg_hpa,
             AVG((batch_json->'summary'->>'accel_rms')::numeric)                AS avg_movement
           FROM sensor_batches
           WHERE user_id = $1
             AND (h3_res9 IS NOT NULL OR batch_json->>'geohash' IS NOT NULL)
           GROUP BY h3_res9, batch_json->>'geohash'
           ORDER BY batch_count DESC
           LIMIT ${MAX_USER_TILES}`,
          [userId],
        );

        // Resolve each row to a final h3 cell. Rows mapping to the same cell are merged.
        // Sensor averages are batch-count-weighted so denser tiles aren't diluted by sparse rows.
        const tileMap = new Map<string, {
          batchCount: number; deviceCount: number; lastUpdate: Date;
          luxSum: number; luxCount: number;
          hpaSum: number; hpaCount: number;
          movementSum: number; movementCount: number;
        }>();
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
            if (row.avg_lux !== null) { existing.luxSum += row.avg_lux * row.batch_count; existing.luxCount += row.batch_count; }
            if (row.avg_hpa !== null) { existing.hpaSum += row.avg_hpa * row.batch_count; existing.hpaCount += row.batch_count; }
            if (row.avg_movement !== null) { existing.movementSum += row.avg_movement * row.batch_count; existing.movementCount += row.batch_count; }
          } else {
            tileMap.set(h3Index, {
              batchCount: row.batch_count, deviceCount: row.device_count, lastUpdate: row.last_update,
              luxSum: row.avg_lux !== null ? row.avg_lux * row.batch_count : 0, luxCount: row.avg_lux !== null ? row.batch_count : 0,
              hpaSum: row.avg_hpa !== null ? row.avg_hpa * row.batch_count : 0, hpaCount: row.avg_hpa !== null ? row.batch_count : 0,
              movementSum: row.avg_movement !== null ? row.avg_movement * row.batch_count : 0, movementCount: row.avg_movement !== null ? row.batch_count : 0,
            });
          }
        }

        const tiles = Array.from(tileMap.entries())
          .sort((a, b) => b[1].batchCount - a[1].batchCount)
          .slice(0, MAX_USER_TILES)
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
              avgLux:      stats.luxCount      > 0 ? Math.round(stats.luxSum      / stats.luxCount)      : null,
              avgHpa:      stats.hpaCount      > 0 ? Math.round((stats.hpaSum     / stats.hpaCount) * 10) / 10 : null,
              avgMovement: stats.movementCount > 0 ? Math.round((stats.movementSum / stats.movementCount) * 100) / 100 : null,
            };
          });

        // Response size guard: truncate tiles if JSON exceeds limit
        const data = { tiles };
        const jsonString = JSON.stringify(data);
        if (Buffer.byteLength(jsonString, 'utf8') > MAX_TILE_RESPONSE_BYTES) {
          const truncatedTiles = tiles.slice(0, Math.floor(tiles.length * 0.8));
          console.warn(`[user tiles] Response size exceeded ${MAX_TILE_RESPONSE_BYTES} bytes, truncated to ${truncatedTiles.length} tiles`);
          return reply.send({ tiles: truncatedTiles });
        }

        return reply.send(data);
      } catch (error) {
        request.log.error({ err: error, userId }, 'Tiles fetch error');
        return reply.code(500).send({ error: 'Internal Server Error', requestId: request.id });
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
        // private: per-user auth, but client can still cache for the TTL window
        reply.header('Cache-Control', `private, max-age=${GLOBAL_TILE_CACHE_TTL_S}`);
        return reply.send(await fetchGlobalTiles());
      } catch (error) {
        request.log.error({ err: error }, 'Global tiles fetch error');
        return reply.code(500).send({ error: 'Internal Server Error', requestId: request.id });
      }
    },
  );

  /**
   * GET /api/stats/global
   * Public community stats — active mapper count + total zones.
   * No auth required. Cached 1 hour — changes slowly.
   */
  fastify.get(
    '/api/stats/global',
    async (request: FastifyRequest, reply: FastifyReply) => {
      const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour
      const CACHE_TTL_S  = 3600;

      // Simple in-memory cache — one slot, no key needed.
      const now = Date.now();
      if (_globalStatsCache && _globalStatsCache.expiresAt > now) {
        reply.header('Cache-Control', `public, max-age=${CACHE_TTL_S}`);
        return reply.send(_globalStatsCache.data);
      }

      try {
        const pool = getPool();
        const result = await pool.query<{
          active_mappers: number;
          total_zones: number;
        }>(
          `SELECT
             COUNT(DISTINCT user_id)::int                                  AS active_mappers,
             COUNT(DISTINCT h3_res9) FILTER (WHERE h3_res9 IS NOT NULL)::int AS total_zones
           FROM sensor_batches
           WHERE timestamp_utc > NOW() - INTERVAL '30 days'`,
        );
        const row = result.rows[0];
        const data = {
          activeMappers: row?.active_mappers ?? 0,
          totalZones:    row?.total_zones    ?? 0,
        };
        _globalStatsCache = { data, expiresAt: now + CACHE_TTL_MS };
        reply.header('Cache-Control', `public, max-age=${CACHE_TTL_S}`);
        return reply.send(data);
      } catch (error) {
        request.log.error({ err: error }, 'Global stats fetch error');
        return reply.code(500).send({ error: 'Internal Server Error', requestId: request.id });
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
        // public: CDN/proxy can cache this — no user-specific data
        reply.header('Cache-Control', `public, max-age=${GLOBAL_TILE_CACHE_TTL_S}, stale-while-revalidate=60`);
        return reply.send(await fetchGlobalTiles());
      } catch (error) {
        request.log.error({ err: error }, 'Public tiles fetch error');
        return reply.code(500).send({ error: 'Internal Server Error', requestId: request.id });
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
        const ConsentBodySchema = z.object({
          platform: z.enum(['android', 'ios']).optional(),
          appVersion: z.string().max(32).optional(),
        });
        const bodyResult = ConsentBodySchema.safeParse(request.body ?? {});
        const { platform, appVersion } = bodyResult.success ? bodyResult.data : {};
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
        request.log.error({ err: error, userId }, 'Consent record error');
        return reply.code(500).send({ error: 'Internal Server Error', requestId: request.id });
      }
    },
  );
}
