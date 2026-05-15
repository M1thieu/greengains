import { LRUCache } from 'lru-cache';
import type { Pool } from 'pg';
import type { UploadBatch } from '../models/upload';
import { EARTH_RADIUS_METERS } from '../constants';
import { vectorMagnitude as vecMagnitude, stdDev } from './sensor-analytics';

// Max batches accepted per device per sliding hour window.
// ~1 batch every 30s for a full hour — generous for real usage, blocks burst bots.
const MAX_BATCHES_PER_HOUR = 120;

// Max batches accepted per user (all their devices combined) per sliding hour window.
// Allows ~2 active devices simultaneously without throttling legitimate users.
const MAX_USER_BATCHES_PER_HOUR = 300;

// Speed threshold for GPS velocity anomaly detection (m/s).
// 100 m/s ≈ 360 km/h — above any road/rail vehicle; tightened from 300 (which let low-altitude aircraft through).
const MAX_GPS_SPEED_MPS = 100;

// ─── In-Memory Rate Limiting ──────────────────────────────────────────────────
//
// Fixed-window counters in an LRU cache — eliminates DB queries for the vast
// majority of requests (normal devices are far below 120 batches/hour).
//
// Architecture:
//   Fast path  — memory count well below limit → return immediately, no DB.
//   Slow path  — memory count at/over limit → confirm against DB to avoid
//               false positives from process restarts resetting counters.
//
// Horizontal scaling: each process has its own memory window; the DB query on
// the slow path is the cross-instance backstop. A legitimate user never reaches
// the slow path; a burst bot gets confirmed and blocked per instance.
//
// Capacity: max=20_000 covers 10 k devices + 10 k users with headroom.
// TTL=1 h matches the rate-limit window so stale buckets self-evict.

interface RateBucket {
  count: number;
  resetAt: number; // epoch ms when this window expires
}

const _rlCache = new LRUCache<string, RateBucket>({
  max: 20_000,
  ttl: 1000 * 60 * 60,
});

function _rlIncrement(key: string): number {
  const now = Date.now();
  const existing = _rlCache.get(key);
  if (!existing || now >= existing.resetAt) {
    const bucket: RateBucket = { count: 1, resetAt: now + 60 * 60 * 1000 };
    _rlCache.set(key, bucket);
    return 1;
  }
  existing.count += 1;
  _rlCache.set(key, existing);
  return existing.count;
}

// ─── Rate Limiting ────────────────────────────────────────────────────────────

/**
 * Checks both device and user rate limits.
 *
 * Fast path (normal requests): O(1) in-memory check — zero DB queries.
 * Slow path (at/over limit): single DB subquery confirms to avoid false
 * positives from process restarts and multi-instance deployments.
 */
export async function checkRateLimits(
  pool: Pool,
  deviceHash: string,
  userId: string | null,
): Promise<{ deviceExceeded: boolean; userExceeded: boolean }> {
  const deviceMem = _rlIncrement(`d:${deviceHash}`);
  const userMem   = userId ? _rlIncrement(`u:${userId}`) : 0;

  const deviceNeedsDb = deviceMem >= MAX_BATCHES_PER_HOUR;
  const userNeedsDb   = userId != null && userMem >= MAX_USER_BATCHES_PER_HOUR;

  if (!deviceNeedsDb && !userNeedsDb) {
    return { deviceExceeded: false, userExceeded: false };
  }

  // Confirm against DB — process restarts reset in-memory counters and could
  // let a burst through. DB is authoritative; memory is just the fast gate.
  const result = await pool.query<{ device_count: string; user_count: string }>(
    `SELECT
       (SELECT COUNT(*)
          FROM sensor_batches
         WHERE device_hash = $1
           AND created_at > NOW() - INTERVAL '1 hour')::text AS device_count,
       (SELECT COUNT(*)
          FROM sensor_batches
         WHERE user_id = $2
           AND created_at > NOW() - INTERVAL '1 hour'
           AND $2 IS NOT NULL)::text AS user_count`,
    [deviceHash, userId],
  );
  const deviceCount = parseInt(result.rows[0]?.device_count ?? '0', 10);
  const userCount   = parseInt(result.rows[0]?.user_count   ?? '0', 10);
  return {
    deviceExceeded: deviceCount >= MAX_BATCHES_PER_HOUR,
    userExceeded:   userId != null && userCount >= MAX_USER_BATCHES_PER_HOUR,
  };
}


// ─── Sensor Range Validation ──────────────────────────────────────────────────

const SENSOR_BOUNDS = {
  light:    { min: 0,    max: 130_000 }, // lux: pitch dark → direct sunlight
  pressure: { min: 870,  max: 1084 },    // hPa: 870 = all-time surface record (Typhoon Tip 1979) → Dead Sea; covers storm chasers
  accelMag: { min: 0,    max: 25 },      // m/s² vector magnitude — ~2.5g, covers hard drops; tightened from 50
  gyroMag:  { min: 0,    max: 15 },      // rad/s vector magnitude — covers vigorous wrist flicks; tightened from 20
  magMag:   { min: 0,    max: 2000 },    // µT magnitude — 4× Earth's strongest field
} as const;


/**
 * Returns the name of the first out-of-range sensor field in the batch, or null if all are valid.
 * Rejects the batch if any single reading contains an implausible value.
 */
export function validateSensorRanges(batch: UploadBatch): string | null {
  for (const r of batch.batch) {
    if (r.light !== undefined) {
      if (r.light < SENSOR_BOUNDS.light.min || r.light > SENSOR_BOUNDS.light.max) return 'light';
    }
    if (r.pressure !== undefined) {
      if (r.pressure < SENSOR_BOUNDS.pressure.min || r.pressure > SENSOR_BOUNDS.pressure.max) return 'pressure';
    }
    if (r.accel !== undefined) {
      if (vecMagnitude(r.accel) > SENSOR_BOUNDS.accelMag.max) return 'accel';
    }
    if (r.gyro !== undefined) {
      if (vecMagnitude(r.gyro) > SENSOR_BOUNDS.gyroMag.max) return 'gyro';
    }
    if (r.magnetic !== undefined && r.magnetic.length === 4) {
      if (r.magnetic[3] > SENSOR_BOUNDS.magMag.max) return 'magnetic';
    }
  }
  return null;
}

// ─── Batch Integrity Checks ───────────────────────────────────────────────────
//
// All checks run in O(n) on the batch array — zero DB queries.
// Return a flag string for logging; callers decide whether to reject or just tag.

/** Max realistic batch window: 30 min. Longer implies buffered/replayed data. */
const MAX_BATCH_WINDOW_MS = 30 * 60 * 1000;

// Hand tremor produces ~0.05–0.15 m/s² std dev. 0.08 caused false-positives on seated users.
// 0.12 requires a truly dead-flat signal before penalizing.
const STATIC_DEVICE_STD_DEV_THRESHOLD = 0.12; // m/s²

/** Min readings to make static-device judgment (short batches = noisy). */
const STATIC_DEVICE_MIN_READINGS = 30;

/** Pocket ratio above this for entire batch = data unusable. */
const HIGH_POCKET_RATIO_THRESHOLD = 0.95;

/** GPS speed above this (m/s) = likely in a vehicle. 15 m/s ≈ 54 km/h (fast cycling / slow car). */
const VEHICLE_SPEED_THRESHOLD_MPS = 15;

/** If this fraction of light readings are exactly 0, the sensor is likely blocked (face-down / case). */
const STUCK_LIGHT_RATIO_THRESHOLD = 0.80;

/** Minimum light readings needed to make the stuck-sensor judgment. */
const STUCK_LIGHT_MIN_READINGS = 15;

/** GPS accuracy above this (metres) = tile attribution is unreliable at res 9 (~174m hex). */
const COARSE_GPS_ACCURACY_M = 150;

/**
 * Max plausible barometric pressure change between consecutive readings (hPa).
 * Ground-level weather fronts: ~10 hPa/hour max; within a batch (minutes), 5 hPa/sample is impossible.
 * Source: NIST/MDPI IoT temporal consistency research; Street Bump pothole delta-threshold pattern.
 */
const MAX_PRESSURE_DELTA_HPA = 5;

/**
 * Minimum consecutive pressure transitions required to judge spike ratio.
 * Short batches with few pressure readings are not reliable enough to penalise.
 */
const PRESSURE_SPIKE_MIN_TRANSITIONS = 5;

/** Fraction of pressure transitions that can be spikes before downweighting. */
const PRESSURE_SPIKE_RATIO_THRESHOLD = 0.15;

/**
 * Max plausible divergence (metres) between GPS altitude and pressure-derived altitude.
 * GPS altitude error is typically ±30–100m; a divergence >300m means one source is bad.
 * Source: Zaliva & Franchetti, CMU — "Barometric and GPS Altitude Sensor Fusion" (2014).
 */
const BARO_GPS_ALTITUDE_DIVERGENCE_M = 300;

/** Sea-level standard pressure for ISA altitude formula (hPa). */
const ISA_SEA_LEVEL_HPA = 1013.25;

export interface BatchIntegrityResult {
  windowTooLong: boolean;   // batch spans more than 30 minutes
  likelyStatic: boolean;    // device never moved — possible fake node
  allPocket: boolean;       // >95% readings in pocket — unusable
  /** GPS speed implies vehicle travel (>15 m/s ≈ 54 km/h) — less useful for pedestrian tiles. */
  highSpeed: boolean;
  /** >80% of light readings are exactly 0 — sensor blocked/face-down, not genuine darkness. */
  lightSensorStuck: boolean;
  /** GPS accuracy too coarse (>150m) for meaningful hex-tile attribution. */
  coarseGps: boolean;
  /**
   * >15% of consecutive pressure transitions exceed 5 hPa — physically implausible on the ground.
   * Source: NIST/MDPI IoT temporal consistency; Street Bump delta-threshold pattern.
   */
  pressureSpikes: boolean;
  /**
   * Reading timestamps are not monotonically increasing — clock skew or corrupted buffer.
   * Source: IoT data quality framework (MDPI 2021) — timeliness & consistency dimensions.
   */
  timestampDisordered: boolean;
  /**
   * Pressure-derived altitude diverges from GPS altitude by >300m.
   * Source: Zaliva & Franchetti, CMU — "Barometric and GPS Altitude Sensor Fusion" (2014).
   */
  baroGpsDivergence: boolean;
  /** 0–1 composite quality multiplier (1.0 = fully trusted, 0.0 = reject). */
  qualityMultiplier: number;
}


/**
 * Pure-compute integrity check on an upload batch.
 * No DB queries — runs at ingest time, costs a single O(n) pass.
 *
 * Catches: suspiciously long capture windows (buffered/replayed batches),
 * devices that never move (fake nodes), and fully-pocketed sessions.
 */
export function checkBatchIntegrity(batch: UploadBatch): BatchIntegrityResult {
  const readings = batch.batch;

  // ── Window duration ───────────────────────────────────────────────────────
  const timestamps = readings.map(r => r.t.getTime()).filter(t => !isNaN(t));
  const windowMs = timestamps.length >= 2
    ? Math.max(...timestamps) - Math.min(...timestamps)
    : 0;
  const windowTooLong = windowMs > MAX_BATCH_WINDOW_MS;

  // ── Static device detection ───────────────────────────────────────────────
  const accelMags = readings
    .filter(r => r.accel !== undefined)
    .map(r => vecMagnitude(r.accel!));
  const likelyStatic =
    accelMags.length >= STATIC_DEVICE_MIN_READINGS &&
    stdDev(accelMags) < STATIC_DEVICE_STD_DEV_THRESHOLD;

  // ── Pocket ratio ──────────────────────────────────────────────────────────
  const pocketReadings = readings.filter(r =>
    String(r.quality?.pocket ?? '').toLowerCase() === 'likely',
  ).length;
  const allPocket =
    readings.length > 0 &&
    pocketReadings / readings.length > HIGH_POCKET_RATIO_THRESHOLD;

  // ── Vehicle speed ─────────────────────────────────────────────────────────
  // batch.location.speed_mps is the GPS-reported speed at batch submission time.
  // > 15 m/s implies a vehicle — pedestrian-scale tile data is less trustworthy.
  const highSpeed = (batch.location?.speed_mps ?? 0) > VEHICLE_SPEED_THRESHOLD_MPS;

  // ── Stuck light sensor ────────────────────────────────────────────────────
  // >80% of light readings exactly 0 → sensor blocked (face-down, dense case).
  // A genuinely dark room has 0–10 lux with slight variation; exactly 0 flat = blocked.
  const lightReadings = readings.filter(r => r.light !== undefined);
  const stuckLightCount = lightReadings.filter(r => r.light! < 0.5).length;
  const lightSensorStuck =
    lightReadings.length >= STUCK_LIGHT_MIN_READINGS &&
    stuckLightCount / lightReadings.length > STUCK_LIGHT_RATIO_THRESHOLD;

  // ── GPS accuracy ──────────────────────────────────────────────────────────
  // accuracy_m > 150m means we can't reliably attribute this batch to a single
  // H3 res-9 hex (~174m diameter). Downweight, but don't reject — coarse GPS
  // is still useful for res-8 global tiles (~461m hex).
  const coarseGps = (batch.location?.accuracy_m ?? 0) > COARSE_GPS_ACCURACY_M;

  // ── Pressure rate-of-change (temporal consistency) ────────────────────────
  // Consecutive readings jumping >5 hPa = sensor glitch, not real weather.
  // Ground-level weather fronts move at ~5–10 hPa/hour; within a batch (minutes)
  // any single-sample jump over 5 hPa is physically impossible.
  // Pattern from: NIST IoT temporal consistency + Street Bump delta-threshold approach.
  const pressureSeq = readings
    .filter(r => r.pressure !== undefined)
    .sort((a, b) => a.t.getTime() - b.t.getTime())
    .map(r => r.pressure!);
  let pressureSpikeCount = 0;
  for (let i = 1; i < pressureSeq.length; i++) {
    if (Math.abs(pressureSeq[i] - pressureSeq[i - 1]) > MAX_PRESSURE_DELTA_HPA) pressureSpikeCount++;
  }
  const pressureTransitions = pressureSeq.length - 1;
  const pressureSpikes =
    pressureTransitions >= PRESSURE_SPIKE_MIN_TRANSITIONS &&
    pressureSpikeCount / pressureTransitions > PRESSURE_SPIKE_RATIO_THRESHOLD;

  // ── Timestamp monotonicity ────────────────────────────────────────────────
  // Readings should be chronologically ordered. Out-of-order timestamps indicate
  // clock skew, corrupted ring buffers, or data replay.
  // Source: MDPI 2021 "Data Quality Management in IoT" — timeliness & consistency dimensions.
  const timestampDisordered =
    timestamps.length >= 3 &&
    !timestamps.every((t, i) => i === 0 || t >= timestamps[i - 1]);

  // ── Barometer ↔ GPS altitude cross-check ─────────────────────────────────
  // Convert mean pressure to altitude using ISA formula, compare to GPS altitude.
  // Divergence >300m = bad GPS altitude or malfunctioning barometer.
  // Source: Zaliva & Franchetti, CMU — "Barometric and GPS Altitude Sensor Fusion" (2014).
  let baroGpsDivergence = false;
  const gpsAltitude = batch.location?.altitude;
  if (gpsAltitude != null && pressureSeq.length >= 3) {
    const avgPressure = pressureSeq.reduce((a, b) => a + b, 0) / pressureSeq.length;
    // International Standard Atmosphere (ISA) altitude formula:
    // alt_m = 44330.8 × (1 − (P / P0) ^ (1/5.2561))
    const baroAltitude = 44330.8 * (1 - Math.pow(avgPressure / ISA_SEA_LEVEL_HPA, 1 / 5.2561));
    baroGpsDivergence = Math.abs(baroAltitude - gpsAltitude) > BARO_GPS_ALTITUDE_DIVERGENCE_M;
  }

  // ── Charging state ────────────────────────────────────────────────────────
  // Charging almost always means the phone is stationary on a desk or in a car.
  // Still useful environmental data, but less valuable for pedestrian tile density.
  // Purple Air uses this same logic to classify indoor vs outdoor nodes.
  const isCharging = batch.is_charging === true;

  // ── Sensor completeness bonus ─────────────────────────────────────────────
  // sensor_flags bitmask: LIGHT=1, MOTION=2, PRESSURE=4, GYRO=8, MAGNETIC=16.
  // More active sensors = more cross-validation possible = higher baseline trust.
  // A batch with all 5 sensors gets a 10% bonus; each missing sensor costs 2%.
  // Capped so this never pushes multiplier above 1.0 — it only partially offsets penalties.
  const sensorCount = batch.sensor_flags != null
    ? [1, 2, 4, 8, 16].filter(bit => (batch.sensor_flags! & bit) !== 0).length
    : 0;
  const sensorBonus = sensorCount >= 4 ? 1.10
    : sensorCount === 3 ? 1.06
    : sensorCount === 2 ? 1.02
    : 1.0;

  // ── Composite quality multiplier ──────────────────────────────────────────
  let qualityMultiplier = 1.0;
  if (windowTooLong)        qualityMultiplier *= 0.5;
  if (likelyStatic)         qualityMultiplier *= 0.3;
  if (allPocket)            qualityMultiplier *= 0.1;
  if (highSpeed)            qualityMultiplier *= 0.4;  // vehicle data less useful for pedestrian tiles
  if (lightSensorStuck)     qualityMultiplier *= 0.7;  // one blocked sensor, others still valid
  if (coarseGps)            qualityMultiplier *= 0.6;  // hex attribution unreliable
  if (pressureSpikes)       qualityMultiplier *= 0.75; // sensor glitch — majority of readings still ok
  if (timestampDisordered)  qualityMultiplier *= 0.8;  // clock skew — readings may still be valid
  if (baroGpsDivergence)    qualityMultiplier *= 0.7;  // one location source is unreliable
  if (isCharging)           qualityMultiplier *= 0.85; // likely stationary/indoors
  qualityMultiplier = Math.min(1.0, qualityMultiplier * sensorBonus); // bonus never exceeds 1.0

  return {
    windowTooLong, likelyStatic, allPocket,
    highSpeed, lightSensorStuck, coarseGps,
    pressureSpikes, timestampDisordered, baroGpsDivergence,
    qualityMultiplier,
  };
}

// ─── GPS Velocity Check ───────────────────────────────────────────────────────

/** Haversine distance in metres between two lat/lon coordinates. */
function haversineMetres(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = EARTH_RADIUS_METERS;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const φ1 = toRad(lat1), φ2 = toRad(lat2);
  const Δφ = toRad(lat2 - lat1), Δλ = toRad(lon2 - lon1);
  const a =
    Math.sin(Δφ / 2) ** 2 +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Returns true if the implied GPS speed between this batch and the previous
 * DB entry for this device exceeds MAX_GPS_SPEED_MPS.
 *
 * Skips the check when:
 * - This batch carries no location data
 * - No previous batch with location exists for this device
 * - Time delta ≤ 0 (clock skew / duplicate timestamp — handled by dedup index)
 */
export async function checkGpsVelocity(
  pool: Pool,
  deviceHash: string,
  batch: UploadBatch,
): Promise<boolean> {
  if (!batch.location) return false;

  const result = await pool.query<{ lat: number; lon: number; ts: Date }>(
    `SELECT
       (batch_json -> 'location' ->> 'lat')::float AS lat,
       (batch_json -> 'location' ->> 'lon')::float AS lon,
       timestamp_utc AS ts
     FROM sensor_batches
    WHERE device_hash = $1
      AND batch_json -> 'location' IS NOT NULL
    ORDER BY timestamp_utc DESC
    LIMIT 1`,
    [deviceHash],
  );

  if (result.rows.length === 0) return false; // first batch for this device

  const prev = result.rows[0];
  const dtSeconds = (batch.timestamp.getTime() - new Date(prev.ts).getTime()) / 1000;
  if (dtSeconds <= 0) return false; // same/older timestamp — dedup index handles this

  const distMetres = haversineMetres(prev.lat, prev.lon, batch.location.lat, batch.location.lon);
  return distMetres / dtSeconds > MAX_GPS_SPEED_MPS;
}
