/// Shared app-wide constants — single source of truth for magic numbers.
/// Import this file instead of repeating literals across screens and services.
library;

// ─── Day / Night Boundary ─────────────────────────────────────────────────────
/// Hour (0–23) at which "day" tiles begin (06:00).
const kDayStartHour = 6;
/// Hour (0–23, exclusive) at which "day" tiles end (20:00 = 8 pm).
/// Use: hour >= kDayStartHour && hour < kDayEndHour
const kDayEndHour = 20;

// ─── API Endpoints ────────────────────────────────────────────────────────────
const kApiUserTiles    = '/api/user/tiles';
const kApiTilesGlobal  = '/api/tiles/global';
const kApiUserProfile  = '/api/user/profile';
const kApiUserConsent  = '/api/user/consent';
const kApiWeeklyTarget = '/api/user/weekly-target';
const kApiLocalRank   = '/api/user/local-rank';
const kApiImpact          = '/api/user/impact';
const kApiWeeklyInsight   = '/api/user/insights/weekly';
const kApiRegisterDevice = '/register-device';
const kApiStatsGlobal  = '/api/stats/global';

// ─── API / Network ────────────────────────────────────────────────────────────
/// Default Dio connect + receive timeout for all backend calls.
/// 60s covers Render free-tier cold starts (30-60s) + slow mobile networks.
const kApiTimeout = Duration(seconds: 60);
/// Short retry delay after a 401 (auth token race on cold start).
const kRetryDelay401 = Duration(seconds: 2);
/// Retry delay after a network / server error on tile load.
const kRetryDelayNetError = Duration(seconds: 4);
/// Retry delay for global tile load errors (slightly longer — lower priority).
const kGlobalTileRetryDelay = Duration(seconds: 5);
/// Maximum number of tile load retries before giving up (avoids infinite loop).
const kMaxTileRetries = 3;
/// How long to wait before showing the "Starting up…" cold-start hint.
const kSlowLoadThreshold = Duration(seconds: 8);

// ─── Upload Queue ────────────────────────────────────────────────────────────
/// Base backoff for exponential retry (30 s → 60 s → 120 s → …).
const kBaseBackoffMs = 30000;

// ─── Location ────────────────────────────────────────────────────────────────
/// GPS timeout when precise (high-accuracy) location is available.
const kPreciseGpsTimeout = Duration(seconds: 15);
/// GPS timeout when only coarse (network/low-accuracy) location is available.
const kCoarseGpsTimeout = Duration(seconds: 5);

// ─── UX Thresholds ────────────────────────────────────────────────────────────
/// Number of successful uploads before requesting an in-app review.
const kReviewRequestThreshold = 5;
/// Minimum gap between battery-optimisation prompt appearances.
const kBatteryPromptInterval = Duration(days: 2);


// ─── H3 / Coverage Geometry ──────────────────────────────────────────────────
/// Approximate area of one H3 res-9 cell in km² (≈ 0.1053 km²).
/// Used to convert cell counts to human-readable area.
const kKm2PerCell = 0.1053;

/// Approximate area of one city block in km² (≈ 0.0092 km²).
/// Used to express coverage in a relatable unit.
const kKm2PerCityBlock = 0.0092;
