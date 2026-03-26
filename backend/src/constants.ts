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
/** Minimum motion_confidence score to consider a reading "in motion". */
export const MOTION_CONFIDENCE_THRESHOLD = 0.2;

// ─── Referral ─────────────────────────────────────────────────────────────────
/** Max collision retry attempts when generating a unique referral code. */
export const MAX_REFERRAL_CODE_RETRIES = 8;

// ─── PostgreSQL Error Codes ───────────────────────────────────────────────────
/** pg error code for unique constraint violation (23505). */
export const PG_UNIQUE_VIOLATION = '23505';
