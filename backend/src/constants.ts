/**
 * Shared constants — single source of truth for all magic numbers.
 * Import from here instead of repeating literals across route files.
 */

// ─── H3 Spatial Indexing ─────────────────────────────────────────────────────
/** Personal tile H3 resolution — ~174m edge length (city block scale). */
export const H3_RES_PERSONAL = 9;
/** Global tile H3 resolution — ~461m edge length (neighbourhood scale). */
export const H3_RES_GLOBAL = 8;

// ─── Tile Query Limits ────────────────────────────────────────────────────────
/** Max H3 tiles returned for a single user's coverage map. */
export const MAX_USER_TILES = 5_000;
/** Max H3 tiles returned for the global community map. */
export const MAX_GLOBAL_TILES = 2_000;

// ─── Time ─────────────────────────────────────────────────────────────────────
export const MS_PER_HOUR = 3_600_000;
export const MS_PER_DAY = 86_400_000;
/** Rolling window for global tile queries (30 days). */
export const GLOBAL_TILE_WINDOW_HOURS = 720;

// ─── Upload / Body ────────────────────────────────────────────────────────────
/** Fastify body size limit: 10 MB. */
export const UPLOAD_BODY_LIMIT_BYTES = 1_048_576 * 10;

// ─── Sentry Sampling ─────────────────────────────────────────────────────────
/** 10% trace/profile sampling — free Sentry tier budget. */
export const SENTRY_TRACES_SAMPLE_RATE = 0.1;
export const SENTRY_PROFILES_SAMPLE_RATE = 0.1;

// ─── Geospatial ───────────────────────────────────────────────────────────────
/** WGS-84 mean Earth radius in metres (Haversine formula). */
export const EARTH_RADIUS_METERS = 6_371_000;

// ─── Sensor Analytics ────────────────────────────────────────────────────────
// 0.2 was too lenient — inflated quality_valid_ratio on borderline-uncertain readings.
// 0.35 requires moderate confidence before a reading counts as valid motion.
export const MOTION_CONFIDENCE_THRESHOLD = 0.35;

// ─── Aggregation Job ─────────────────────────────────────────────────────────
/** Bucket width for the 5-minute aggregate table. */
export const AGGREGATION_WINDOW_MINUTES = 5;
/** How often the aggregation job polls for new batches (1 minute). */
export const AGGREGATION_JOB_INTERVAL_MS = 60_000;
/** Accelerometer reading when phone is at rest (gravity component, m/s²). */
export const MOVEMENT_GRAVITY_BASELINE = 9.81;
/** Deviation above/below rest that maps to movement_score = 1.0. */
export const MOVEMENT_THRESHOLD = 5.0;

// ─── Data Retention ───────────────────────────────────────────────────────────
/**
 * How long raw sensor_batches rows are kept before purge.
 * Aggregated data (sensor_aggregates_5m / _daily) is kept indefinitely.
 * 90 days gives B2B customers enough window for re-processing while
 * preventing unbounded table growth.
 */
export const SENSOR_BATCH_RETENTION_DAYS = 90;

// ─── Referral ─────────────────────────────────────────────────────────────────
/** Max collision retry attempts when generating a unique referral code. */
export const MAX_REFERRAL_CODE_RETRIES = 8;

// ─── PostgreSQL Error Codes ───────────────────────────────────────────────────
/** pg error code for unique constraint violation (23505). */
export const PG_UNIQUE_VIOLATION = '23505';

// ─── Database ─────────────────────────────────────────────────────────────────
/** Max connections in the pg.Pool (Supabase free tier caps at 60). */
export const DB_POOL_MAX = 10;

// ─── HTTP Response Limits ─────────────────────────────────────────────────────
/** Max JSON response size for tile endpoints (1 MB). */
export const MAX_TILE_RESPONSE_BYTES = 1_048_576;

// ─── Tile Confidence Thresholds ───────────────────────────────────────────────
/** Personal tiles: batch count that maps to confidence = 1.0. */
export const CONFIDENCE_BATCH_THRESHOLD = 10;
/** Global tiles: sample count that maps to confidence = 1.0. */
export const CONFIDENCE_SAMPLE_THRESHOLD = 100;

// ─── Global Tile Cache ────────────────────────────────────────────────────────
/** In-process cache TTL for global tile responses (5 minutes). */
export const GLOBAL_TILE_CACHE_TTL_MS = 5 * 60 * 1_000;
/** Cache-Control max-age value matching GLOBAL_TILE_CACHE_TTL_MS (seconds). */
export const GLOBAL_TILE_CACHE_TTL_S = 5 * 60;

// ─── Profile Cache ────────────────────────────────────────────────────────────
/** In-process per-user profile cache TTL (1 hour). */
export const PROFILE_CACHE_TTL_MS = 60 * 60 * 1_000;

// ─── Global Stats Cache ───────────────────────────────────────────────────────
/** In-process cache TTL for global stats (active mappers / total zones) — 1 hour. */
export const GLOBAL_STATS_CACHE_TTL_MS = 60 * 60 * 1_000;
/** Cache-Control max-age matching GLOBAL_STATS_CACHE_TTL_MS (seconds). */
export const GLOBAL_STATS_CACHE_TTL_S  = 60 * 60;

// ─── Device Limits ────────────────────────────────────────────────────────────
/** Max registered devices per user (oldest evicted on overflow). */
export const MAX_DEVICES_PER_USER = 10;

// ─── Database Connection Retry ────────────────────────────────────────────────
/** Max attempts for initial DB connection on cold start. */
export const DB_RETRY_MAX_ATTEMPTS = 5;
/** Base delay (ms) for DB retry backoff — multiplied by attempt number. */
export const DB_RETRY_BASE_DELAY_MS = 2_000;

// ─── H3 Backfill ─────────────────────────────────────────────────────────────
/** Rows processed per batch in the H3 backfill job. */
export const H3_BACKFILL_BATCH_SIZE = 500;

// ─── Referral Codes ───────────────────────────────────────────────────────────
/** Unambiguous character set — excludes 0/O and 1/I to avoid confusion. */
export const REFERRAL_CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
/** Regex that a valid referral code must match. */
export const REFERRAL_CODE_PATTERN = /^GG-[A-Z0-9]{5}$/;
