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
  PROFILE_CACHE_TTL_MS,
  GLOBAL_STATS_CACHE_TTL_MS,
  GLOBAL_STATS_CACHE_TTL_S,
} from '../constants';

// ─── In-memory cache for global tiles (5-min TTL, avoids per-request DB hits) ─
interface TileCacheEntry { data: unknown; expiresAt: number; }
const _globalTileCache = new Map<string, TileCacheEntry>();

// ─── In-memory cache for global stats (1-hour TTL) ───────────────────────────
interface StatsCacheEntry { data: { activeMappers: number; totalZones: number }; expiresAt: number; }
let _globalStatsCache: StatsCacheEntry | null = null;

// ─── Per-user profile cache (1h TTL) ─────────────────────────────────────────
// Eliminates repeated DB hits on every stats screen open / app resume.
// Invalidated on upload (via invalidateProfileCache) so fresh data appears
// quickly after a user uploads — acceptable staleness for a stats view.
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
    const stats = await fetchUserProfileData(pool, userId);
    if (!stats) return; // No data yet — nothing to cache.

    await pool.query(
      `INSERT INTO user_profile_cache (
         user_id, total_batches, coverage_cells, days_active,
         current_streak, longest_streak, first_upload_at, last_upload_at, updated_at
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
       ON CONFLICT (user_id) DO UPDATE SET
         total_batches   = EXCLUDED.total_batches,
         coverage_cells  = EXCLUDED.coverage_cells,
         days_active     = EXCLUDED.days_active,
         current_streak  = EXCLUDED.current_streak,
         longest_streak  = EXCLUDED.longest_streak,
         first_upload_at = EXCLUDED.first_upload_at,
         last_upload_at  = EXCLUDED.last_upload_at,
         updated_at      = EXCLUDED.updated_at`,
      [
        userId,
        stats.total_batches,
        stats.coverage_cells,
        stats.days_active,
        stats.current_streak,
        stats.longest_streak,
        stats.first_upload_date,
        stats.last_upload_date,
      ],
    );
  } catch {
    // Non-fatal — error is logged by the caller (upload route) via fastify.log.
  }
}

// ─── Shared profile stats query ───────────────────────────────────────────────

interface UserProfileStats {
  total_batches: number;
  days_active: number;
  coverage_cells: number;
  first_upload_date: Date | null;
  last_upload_date: Date | null;
  longest_streak: number;
  current_streak: number;
}

/**
 * Fetches scalar profile stats for a user in a single CTE pass over sensor_batches.
 * Used by both the profile endpoint (cache-miss path) and refreshUserProfileCache.
 */
async function fetchUserProfileData(pool: ReturnType<typeof getPool>, userId: string): Promise<UserProfileStats | null> {
  const result = await pool.query<UserProfileStats>(
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
  return result.rows[0] ?? null;
}

// ─── Shared global tile query ─────────────────────────────────────────────────

/**
 * Fetches global community tiles from sensor_aggregates_daily.
 * Uses the daily table for the 30-day window — 288x fewer rows than 5m table,
 * same data quality for a coverage map. Results are cached 5 min in-memory.
 * Falls back to geohash decode for rows without h3_index.
 */
async function fetchGlobalTiles(log?: { warn: (obj: unknown, msg: string) => void }): Promise<unknown> {
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
    vibration_score: number | null;
    avg_light: number | null;
    last_update: Date;
  }>(
    `SELECT
       geohash,
       SUM(samples_count)::int                AS sample_count,
       MAX(device_count)::int                 AS device_count,
       AVG(quality_valid_ratio)               AS quality_valid_ratio,
       AVG(vibration_score)                   AS vibration_score,
       AVG(avg_light)                         AS avg_light,
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
        confidence:    sampleConfidence,
        qualityScore,
        qualityValidRatio: row.quality_valid_ratio !== null ? Math.round(qualityValidRatio * 100) / 100 : null,
        deviceCount:   row.device_count,
        sampleCount:   row.sample_count,
        lastUpdate:    row.last_update,
        avgLux:        row.avg_light !== null ? Math.round(row.avg_light * 10) / 10 : null,
        vibrationScore: row.vibration_score !== null ? Math.round((row.vibration_score ?? 0) * 100) / 100 : null,
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
    log?.warn({ limit: MAX_TILE_RESPONSE_BYTES, truncatedTo: truncatedTiles.length }, 'Global tiles response size exceeded limit, truncated');
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
        const [liveResult, weeklyResult, qualityResult, bestDayResult] = await Promise.all([
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
          pool.query<{ best_day_count: number }>(
            `SELECT COUNT(*)::int AS best_day_count
             FROM sensor_batches
             WHERE user_id = $1
             GROUP BY DATE(timestamp_utc)
             ORDER BY best_day_count DESC
             LIMIT 1`,
            [userId],
          ),
        ]);

        const qr = qualityResult.rows[0];
        const qualityPct = (qr?.samples_count ?? 0) > 0
          ? Math.round((qr.valid_samples / qr.samples_count) * 100)
          : null;
        const bestDayCount = bestDayResult.rows[0]?.best_day_count ?? 0;

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
          // Cache miss — shared helper scans sensor_batches once for all scalar stats + streak.
          const m = await fetchUserProfileData(pool, userId);
          totalUploads    = m?.total_batches     ?? 0;
          coverageCells   = m?.coverage_cells    ?? 0;
          daysActive      = m?.days_active       ?? 0;
          currentStreak   = m?.current_streak    ?? 0;
          longestStreak   = m?.longest_streak    ?? 0;
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
            bestDayCount,
            avgPerDay: daysActive > 0 ? Math.round((totalUploads / daysActive) * 10) / 10 : 0,
          },
        };
        _profileCache.set(userId, { data: profileData, expiresAt: Date.now() + PROFILE_CACHE_TTL_MS });
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
          avg_lux_night: number | null;
          avg_lux_day: number | null;
          avg_hpa: number | null;
          avg_movement: number | null;
          avg_accel_std_dev: number | null;
          avg_vibration_vehicle: number | null;
          avg_wifi_ap_count: number | null;
          avg_magnetic: number | null;
          avg_quality_ratio: number | null;
        }>(
          `SELECT
             h3_res9,
             batch_json->>'geohash'                                                        AS geohash,
             COUNT(*)::int                                                                  AS batch_count,
             COUNT(DISTINCT device_hash)::int                                               AS device_count,
             MAX(timestamp_utc)                                                             AS last_update,
             AVG((batch_json->'summary'->'light'->>'avg')::numeric)                        AS avg_lux,
             AVG(CASE WHEN EXTRACT(hour FROM timestamp_utc) >= 22
                        OR EXTRACT(hour FROM timestamp_utc) < 6
                  THEN (batch_json->'summary'->'light'->>'avg')::numeric END)              AS avg_lux_night,
             AVG(CASE WHEN EXTRACT(hour FROM timestamp_utc) BETWEEN 6 AND 21
                  THEN (batch_json->'summary'->'light'->>'avg')::numeric END)              AS avg_lux_day,
             AVG((batch_json->'summary'->'pressure'->>'avg')::numeric)                     AS avg_hpa,
             AVG((batch_json->'summary'->>'accel_rms')::numeric)                           AS avg_movement,
             AVG((batch_json->'summary'->>'accel_std_dev')::numeric)                       AS avg_accel_std_dev,
             AVG(CASE WHEN batch_json->'summary'->>'transport_mode' = 'vehicle'
                  THEN (batch_json->'summary'->>'accel_std_dev')::numeric END)             AS avg_vibration_vehicle,
             AVG((batch_json->>'wifi_ap_count')::numeric)                                  AS avg_wifi_ap_count,
             AVG((batch_json->'summary'->'magnetic_magnitude'->>'avg')::numeric)           AS avg_magnetic,
             AVG(
               (batch_json->'summary'->>'quality_valid')::numeric
               / NULLIF((batch_json->'summary'->>'count')::numeric, 0)
             )                                                                              AS avg_quality_ratio
           FROM sensor_batches
           WHERE user_id = $1
             AND (h3_res9 IS NOT NULL OR batch_json->>'geohash' IS NOT NULL)
             AND (
               (batch_json->'location'->>'accuracy_m') IS NULL
               OR (batch_json->'location'->>'accuracy_m')::float <= 100
             )
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
          luxNightSum: number; luxNightCount: number;
          luxDaySum: number; luxDayCount: number;
          hpaSum: number; hpaCount: number;
          movementSum: number; movementCount: number;
          vibrationSum: number; vibrationCount: number;
          vibrationVehicleSum: number; vibrationVehicleCount: number;
          wifiApSum: number; wifiApCount: number;
          magneticSum: number; magneticCount: number;
          qualitySum: number; qualityCount: number;
        }>();
        for (const row of tilesResult.rows) {
          let h3Index: string | null = row.h3_res9;
          if (!h3Index && row.geohash) {
            const centroid = decodeGeohash(row.geohash);
            if (!centroid) continue;
            h3Index = latLngToCell(centroid.lat, centroid.lon, 9);
          }
          if (!h3Index) continue;
          const n = row.batch_count;
          const existing = tileMap.get(h3Index);
          if (existing) {
            existing.batchCount += n;
            existing.deviceCount = Math.max(existing.deviceCount, row.device_count);
            if (row.last_update > existing.lastUpdate) existing.lastUpdate = row.last_update;
            if (row.avg_lux !== null)               { existing.luxSum               += row.avg_lux               * n; existing.luxCount               += n; }
            if (row.avg_lux_night !== null)         { existing.luxNightSum          += row.avg_lux_night         * n; existing.luxNightCount          += n; }
            if (row.avg_lux_day !== null)           { existing.luxDaySum            += row.avg_lux_day           * n; existing.luxDayCount            += n; }
            if (row.avg_hpa !== null)               { existing.hpaSum               += row.avg_hpa               * n; existing.hpaCount               += n; }
            if (row.avg_movement !== null)          { existing.movementSum          += row.avg_movement          * n; existing.movementCount          += n; }
            if (row.avg_accel_std_dev !== null)     { existing.vibrationSum         += row.avg_accel_std_dev     * n; existing.vibrationCount         += n; }
            if (row.avg_vibration_vehicle !== null) { existing.vibrationVehicleSum  += row.avg_vibration_vehicle * n; existing.vibrationVehicleCount  += n; }
            if (row.avg_wifi_ap_count !== null)     { existing.wifiApSum            += row.avg_wifi_ap_count     * n; existing.wifiApCount            += n; }
            if (row.avg_magnetic !== null)          { existing.magneticSum          += row.avg_magnetic          * n; existing.magneticCount          += n; }
            if (row.avg_quality_ratio !== null)     { existing.qualitySum           += row.avg_quality_ratio     * n; existing.qualityCount           += n; }
          } else {
            const w = (v: number | null) => v !== null ? v * n : 0;
            const c = (v: number | null) => v !== null ? n : 0;
            tileMap.set(h3Index, {
              batchCount: n, deviceCount: row.device_count, lastUpdate: row.last_update,
              luxSum:              w(row.avg_lux),               luxCount:              c(row.avg_lux),
              luxNightSum:         w(row.avg_lux_night),         luxNightCount:         c(row.avg_lux_night),
              luxDaySum:           w(row.avg_lux_day),           luxDayCount:           c(row.avg_lux_day),
              hpaSum:              w(row.avg_hpa),               hpaCount:              c(row.avg_hpa),
              movementSum:         w(row.avg_movement),          movementCount:         c(row.avg_movement),
              vibrationSum:        w(row.avg_accel_std_dev),     vibrationCount:        c(row.avg_accel_std_dev),
              vibrationVehicleSum: w(row.avg_vibration_vehicle), vibrationVehicleCount: c(row.avg_vibration_vehicle),
              wifiApSum:           w(row.avg_wifi_ap_count),     wifiApCount:           c(row.avg_wifi_ap_count),
              magneticSum:         w(row.avg_magnetic),          magneticCount:         c(row.avg_magnetic),
              qualitySum:          w(row.avg_quality_ratio),     qualityCount:          c(row.avg_quality_ratio),
            });
          }
        }

        const tiles = Array.from(tileMap.entries())
          .sort((a, b) => b[1].batchCount - a[1].batchCount)
          .slice(0, MAX_USER_TILES)
          .map(([h3Index, stats]) => {
            const boundary = cellToBoundary(h3Index, true) as [number, number][];
            const [lat, lng] = cellToLatLng(h3Index);
            const rawVibration = stats.vibrationCount > 0 ? stats.vibrationSum / stats.vibrationCount : null;
            const rawVibrationVehicle = stats.vibrationVehicleCount > 0 ? stats.vibrationVehicleSum / stats.vibrationVehicleCount : null;
            return {
              h3Index,
              boundary,
              centroid: { lat, lng },
              confidence:         Math.min(1.0, stats.batchCount / CONFIDENCE_BATCH_THRESHOLD),
              sampleCount:        stats.batchCount,
              deviceCount:        stats.deviceCount,
              lastUpdate:         stats.lastUpdate,
              avgLux:             stats.luxCount           > 0 ? Math.round(stats.luxSum            / stats.luxCount)                                        : null,
              avgLuxNight:        stats.luxNightCount      > 0 ? Math.round(stats.luxNightSum        / stats.luxNightCount)                                   : null,
              avgLuxDay:          stats.luxDayCount        > 0 ? Math.round(stats.luxDaySum          / stats.luxDayCount)                                     : null,
              avgHpa:             stats.hpaCount           > 0 ? Math.round((stats.hpaSum            / stats.hpaCount) * 10) / 10                             : null,
              avgMovement:        stats.movementCount      > 0 ? Math.round((stats.movementSum       / stats.movementCount) * 100) / 100                      : null,
              avgVibration:       rawVibration        !== null  ? Math.round(Math.min(1, rawVibration        / 5.0) * 100) / 100                              : null,
              avgVibrationVehicle:rawVibrationVehicle !== null  ? Math.round(Math.min(1, rawVibrationVehicle / 5.0) * 100) / 100                              : null,
              avgWifiApCount:     stats.wifiApCount        > 0 ? Math.round(stats.wifiApSum          / stats.wifiApCount)                                     : null,
              avgMagnetic:        stats.magneticCount      > 0 ? Math.round((stats.magneticSum        / stats.magneticCount) * 10) / 10                         : null,
              qualityRatio:       stats.qualityCount       > 0 ? Math.round((stats.qualitySum        / stats.qualityCount) * 100) / 100                       : null,
            };
          });

        // Response size guard: truncate tiles if JSON exceeds limit
        const data = { tiles };
        const jsonString = JSON.stringify(data);
        if (Buffer.byteLength(jsonString, 'utf8') > MAX_TILE_RESPONSE_BYTES) {
          const truncatedTiles = tiles.slice(0, Math.floor(tiles.length * 0.8));
          request.log.warn({ limit: MAX_TILE_RESPONSE_BYTES, truncatedTo: truncatedTiles.length, userId }, 'User tiles response size exceeded limit, truncated');
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
        return reply.send(await fetchGlobalTiles(request.log));
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
      // Simple in-memory cache — one slot, no key needed.
      const now = Date.now();
      if (_globalStatsCache && _globalStatsCache.expiresAt > now) {
        reply.header('Cache-Control', `public, max-age=${GLOBAL_STATS_CACHE_TTL_S}`);
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
        _globalStatsCache = { data, expiresAt: now + GLOBAL_STATS_CACHE_TTL_MS };
        reply.header('Cache-Control', `public, max-age=${GLOBAL_STATS_CACHE_TTL_S}`);
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
        return reply.send(await fetchGlobalTiles(request.log));
      } catch (error) {
        request.log.error({ err: error }, 'Public tiles fetch error');
        return reply.code(500).send({ error: 'Internal Server Error', requestId: request.id });
      }
    },
  );

  /**
   * GET /api/user/weekly-target
   * Returns the user's new-territory progress for the current week (Sun–Sat UTC).
   * "New" cells = h3_res9 seen this week that were never seen in any prior week.
   */
  fastify.get(
    '/api/user/weekly-target',
    { preHandler: requireFirebaseAuth },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.uid;
      try {
        const pool = getPool();

        // Compute last Sunday 00:00:00 UTC.
        const now = new Date();
        const dayOfWeek = now.getUTCDay(); // 0 = Sunday
        const weekStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - dayOfWeek));
        const weekEnd   = new Date(weekStart.getTime() + 7 * MS_PER_DAY - 1); // Saturday 23:59:59.999 UTC

        const result = await pool.query<{ new_cells: string }>(
          `WITH week_cells AS (
             SELECT DISTINCT h3_res9 FROM sensor_batches
             WHERE user_id = $1 AND h3_res9 IS NOT NULL
               AND timestamp_utc >= $2
           ),
           prior_cells AS (
             SELECT DISTINCT h3_res9 FROM sensor_batches
             WHERE user_id = $1 AND h3_res9 IS NOT NULL
               AND timestamp_utc < $2
           )
           SELECT COUNT(*)::text AS new_cells FROM week_cells
           WHERE h3_res9 NOT IN (SELECT h3_res9 FROM prior_cells)`,
          [userId, weekStart.toISOString()],
        );

        const newCells = parseInt(result.rows[0]?.new_cells ?? '0', 10);
        const target = 5;

        return reply.send({
          week_start:          weekStart.toISOString().slice(0, 10),
          week_end:            weekEnd.toISOString().slice(0, 10),
          new_cells_this_week: newCells,
          target,
          pct_complete:        Math.min(1, newCells / target),
        });
      } catch (error) {
        request.log.error({ err: error, userId }, 'Weekly target fetch error');
        return reply.code(500).send({ error: 'Internal Server Error', requestId: request.id });
      }
    },
  );

  /**
   * GET /api/user/local-rank
   * "Local Legend" status — ranks the user against everyone else who mapped
   * inside their most-active h3_res8 cell (~461m hex, same granularity as
   * community tiles) this week. No tokens, no other user identities exposed —
   * pure local status, mirroring Strava's Local Legend retention mechanic
   * (consistency-based, achievable, no global leaderboard demotivation).
   */
  fastify.get(
    '/api/user/local-rank',
    { preHandler: requireFirebaseAuth },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.uid;
      try {
        const pool = getPool();

        const now = new Date();
        const dayOfWeek = now.getUTCDay();
        const weekStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - dayOfWeek));
        const weekEnd   = new Date(weekStart.getTime() + 7 * MS_PER_DAY - 1);

        // Find the h3_res8 cell the user has been most active in this week.
        const homeResult = await pool.query<{ h3_res8: string; batch_count: string }>(
          `SELECT h3_res8, COUNT(*)::text AS batch_count
           FROM sensor_batches
           WHERE user_id = $1 AND h3_res8 IS NOT NULL AND timestamp_utc >= $2
           GROUP BY h3_res8
           ORDER BY batch_count DESC
           LIMIT 1`,
          [userId, weekStart.toISOString()],
        );

        const homeCell = homeResult.rows[0]?.h3_res8 ?? null;
        if (!homeCell) {
          return reply.send({
            hasActivity: false,
            weekStart: weekStart.toISOString().slice(0, 10),
            weekEnd:   weekEnd.toISOString().slice(0, 10),
          });
        }

        // Rank every mapper active in that same cell this week by distinct cells covered.
        const rankResult = await pool.query<{ user_id: string; cell_count: string }>(
          `SELECT user_id, COUNT(DISTINCT h3_res9)::text AS cell_count
           FROM sensor_batches
           WHERE h3_res8 = $1 AND timestamp_utc >= $2 AND h3_res9 IS NOT NULL
           GROUP BY user_id
           ORDER BY cell_count DESC`,
          [homeCell, weekStart.toISOString()],
        );

        const rows = rankResult.rows.map(r => ({ userId: r.user_id, cellCount: parseInt(r.cell_count, 10) }));
        const totalMappers = rows.length;
        const ownIndex = rows.findIndex(r => r.userId === userId);
        const rank = ownIndex === -1 ? totalMappers + 1 : ownIndex + 1;
        const ownCellCount = ownIndex === -1 ? 0 : rows[ownIndex].cellCount;
        const leaderCellCount = rows[0]?.cellCount ?? 0;
        const isLeader = rank === 1;

        return reply.send({
          hasActivity: true,
          rank,
          totalMappers,
          isLeader,
          ownCellCount,
          leaderCellCount,
          cellsToLead: isLeader ? 0 : Math.max(1, leaderCellCount - ownCellCount + 1),
          weekStart: weekStart.toISOString().slice(0, 10),
          weekEnd:   weekEnd.toISOString().slice(0, 10),
        });
      } catch (error) {
        request.log.error({ err: error, userId }, 'Local rank fetch error');
        return reply.code(500).send({ error: 'Internal Server Error', requestId: request.id });
      }
    },
  );

  /**
   * GET /api/user/impact
   * "Only you" signal — counts how many of the user's own h3_res9 cells have
   * never been mapped by anyone else, ever. Closes the citizen-science
   * "fulfillment gap" (Frontiers 2023: contribution satisfaction drops after
   * joining because people never see what their data actually did) with a
   * concrete, true number rather than a generic thank-you.
   */
  fastify.get(
    '/api/user/impact',
    { preHandler: requireFirebaseAuth },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.uid;
      try {
        const pool = getPool();

        const result = await pool.query<{ total_cells: string; solo_cells: string }>(
          `WITH my_cells AS (
             SELECT DISTINCT h3_res9 FROM sensor_batches
             WHERE user_id = $1 AND h3_res9 IS NOT NULL
             LIMIT ${MAX_USER_TILES}
           ),
           contributor_counts AS (
             SELECT sb.h3_res9, COUNT(DISTINCT sb.user_id) AS contributors
             FROM sensor_batches sb
             WHERE sb.h3_res9 IN (SELECT h3_res9 FROM my_cells)
             GROUP BY sb.h3_res9
           )
           SELECT
             (SELECT COUNT(*) FROM my_cells)::text                                AS total_cells,
             (SELECT COUNT(*) FROM contributor_counts WHERE contributors = 1)::text AS solo_cells`,
          [userId],
        );

        const totalCells = parseInt(result.rows[0]?.total_cells ?? '0', 10);
        const soloCells  = parseInt(result.rows[0]?.solo_cells ?? '0', 10);

        return reply.send({
          hasActivity: totalCells > 0,
          totalCells,
          soloCells,
        });
      } catch (error) {
        request.log.error({ err: error, userId }, 'Impact fetch error');
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
