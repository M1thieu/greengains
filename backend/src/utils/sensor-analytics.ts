/**
 * Sensor Analytics Utilities
 *
 * Shared functions for analyzing sensor data quality and calculating metrics.
 * Used by both upload route (real-time) and aggregation job (batch processing).
 */

import { SensorReading } from '../models/upload';
import { MOTION_CONFIDENCE_THRESHOLD } from '../constants';

export interface QualityCounters {
  total: number;
  valid: number;
  pocketLikely: number;
}

export interface Summary {
  count: number;
  period_start: Date;
  period_end: Date;
  light?: { avg: number; min: number; max: number };
  /** Mean accel magnitude after MAD filter (NOT true RMS — mislabeled; rename would break existing JSONB). */
  accel_rms: number;
  /** Mean gyro magnitude after MAD filter (same naming caveat as accel_rms). */
  gyro_rms: number;
  pressure?: { avg: number; min: number; max: number };
  magnetic_magnitude?: { avg: number; min: number; max: number };
  /**
   * Extra channels only some phones have (ambient temperature, humidity, rear light, chip
   * temperatures), one entry per key, MAD-filtered like the core sensors. Present so queries
   * never have to unnest the raw readings array.
   */
  aux?: Record<string, { avg: number; min: number; max: number; n: number }>;
  /** Std dev of raw accel magnitudes — high = rough surface / vibration. */
  accel_std_dev: number;
  /** Quality counters baked in at ingest so the aggregator never needs the raw batch array. */
  quality_valid: number;
  quality_pocket_likely: number;
  /** Inferred from GPS speed: stationary / walking / vehicle / unknown */
  transport_mode?: string;
}

/**
 * Median Absolute Deviation outlier filter (openSenseMap/MAD pattern).
 *
 * Returns the subset of values within `multiplier` standard deviations of the median, where the
 * standard deviation is estimated robustly as 1.4826 × MAD. If fewer than 4 values are provided,
 * or if MAD is 0 (all identical), the original array is returned unchanged (no false positives on
 * flat signals).
 *
 * Why 1.4826: for Gaussian data MAD = 0.6745 σ, so the raw MAD underestimates σ by that factor and
 * "3 × MAD" is really a 2 σ cut that discards ~5 % of perfectly good samples (measured: 5.1 %,
 * sensor-analytics.test.ts). The consistency constant is 1 / Φ⁻¹(3/4) (Rousseeuw & Croux 1993).
 * With it, `multiplier = 3` means 3 σ, i.e. 0.27 % of clean Gaussian data.
 *
 * Reference: openSenseMap outlierTransformer uses a 3σ-equivalent MAD threshold.
 */
const MAD_TO_SIGMA = 1.4826;

export function filterOutliersMad(values: number[], multiplier = 3): number[] {
  if (values.length < 4) return values;

  const sorted = [...values].sort((a, b) => a - b);
  const mid = sorted.length / 2;
  const median = sorted.length % 2 === 0
    ? (sorted[mid - 1] + sorted[mid]) / 2
    : sorted[Math.floor(mid)];

  const deviations = values.map(v => Math.abs(v - median)).sort((a, b) => a - b);
  const devMid = deviations.length / 2;
  const mad = deviations.length % 2 === 0
    ? (deviations[devMid - 1] + deviations[devMid]) / 2
    : deviations[Math.floor(devMid)];

  if (mad === 0) return values; // flat signal — every value is the median, no outliers

  const threshold = multiplier * MAD_TO_SIGMA * mad;
  return values.filter(v => Math.abs(v - median) <= threshold);
}

/**
 * Calculate the magnitude of a 3D vector (e.g., accelerometer, gyroscope)
 * @param vector Array of [x, y, z] components
 * @returns Magnitude (sqrt(x² + y² + z²))
 */
export function vectorMagnitude(vector: number[]): number {
  return Math.sqrt(vector.reduce((sum, component) => sum + component ** 2, 0));
}

export function stdDev(values: number[]): number {
  if (values.length < 2) return 0;
  const mean = values.reduce((a, b) => a + b, 0) / values.length;
  return Math.sqrt(values.reduce((a, b) => a + (b - mean) ** 2, 0) / values.length);
}

/**
 * Analyze sensor reading quality metrics
 *
 * Categorizes readings as:
 * - total: readings with quality metadata
 * - valid: readings with acceptable location/motion quality
 * - pocketLikely: readings likely from device in pocket (exclude from analysis)
 *
 * @param readings Array of sensor readings with optional quality metadata
 * @returns Quality counters for the batch
 */
/**
 * Weighted quality score for a single reading (0.0–1.0).
 *
 * Replaces the old OR logic (too permissive — pocket-free + any signal = valid).
 * Now requires a composite score ≥ QUALITY_COMPOSITE_THRESHOLD across three axes:
 *   • Location accuracy  (45% weight)
 *   • Motion confidence  (35% weight)
 *   • Exposure / pocket  (20% weight)
 *
 * A reading with poor GPS AND unknown motion no longer passes — it needs at least
 * two decent signals, not just one.
 */
const QUALITY_COMPOSITE_THRESHOLD = 0.42;

const LOCATION_SCORES: Record<string, number> = {
  high: 1.0, medium: 0.7, low: 0.4, poor: 0.1, stale: 0.05,
};

/**
 * Convert GPS accuracy_m to a continuous location score (0–1).
 * Replaces coarse string buckets when the device reports actual accuracy in metres.
 * Calibrated against H3 res-9 hex diameter (~174m): ≤10m = excellent, >150m = unusable.
 */
function accuracyMToLocScore(m: number): number {
  if (m <= 10)  return 1.0;
  if (m <= 30)  return 0.85;
  if (m <= 60)  return 0.65;
  if (m <= 100) return 0.40;
  if (m <= 150) return 0.20;
  return 0.05;
}

function readingQualityScore(
  quality: {
    pocket?: unknown;
    location_quality?: unknown;
    motion_state?: unknown;
    motion_confidence?: unknown;
    proximity_near?: unknown;
    orientation?: unknown;
  },
  batchAccuracyM?: number,
): number {
  const pocket = String(quality.pocket ?? '').toLowerCase();
  if (pocket === 'likely') return 0; // automatic disqualifier

  // proximity_near (phone pressed against surface) and face_down orientation are
  // direct "sensors blocked" signals — treat same as pocket: likely.
  // Source: same physical occlusion logic as pocket detection; these fields were
  // already collected but never scored.
  const orientation = String(quality.orientation ?? '').toLowerCase();
  if (quality.proximity_near === true || orientation === 'face_down') return 0;

  // Prefer continuous accuracy_m over coarse string bucket when available.
  const locScore = batchAccuracyM != null
    ? accuracyMToLocScore(batchAccuracyM)
    : (LOCATION_SCORES[String(quality.location_quality ?? '').toLowerCase()] ?? 0.15);

  const motionConf = typeof quality.motion_confidence === 'number' ? quality.motion_confidence : 0;
  const motionState = String(quality.motion_state ?? '').toLowerCase();
  const motionScore = motionState === 'unknown'
    ? 0.15
    : Math.max(MOTION_CONFIDENCE_THRESHOLD, motionConf);
  // face_up = sensor clearly exposed to environment (not blocked by surface or clothing)
  const exposureScore = pocket === 'unlikely' ? 1.0 : orientation === 'face_up' ? 0.85 : 0.5;

  return locScore * 0.45 + motionScore * 0.35 + exposureScore * 0.20;
}

/**
 * True when the light sensor was covered (pocket, proximity sensor near, or
 * screen face down), so its value says nothing about ambient light. Light
 * gated by proximity is how IODetector (Li et al. 2014) gets usable readings.
 */
export function lightOccluded(quality: SensorReading['quality']): boolean {
  if (!quality) return false;
  return String(quality.pocket ?? '').toLowerCase() === 'likely' ||
    quality.proximity_near === true ||
    String(quality.orientation ?? '').toLowerCase() === 'face_down';
}

export function analyzeQuality(readings: SensorReading[], batchAccuracyM?: number): QualityCounters {
  const counters: QualityCounters = { total: 0, valid: 0, pocketLikely: 0 };

  if (!Array.isArray(readings)) return counters;

  for (const reading of readings) {
    const quality = reading?.quality;
    if (!quality) continue;

    counters.total += 1;

    const pocket = String(quality.pocket ?? '').toLowerCase();
    if (pocket === 'likely') {
      counters.pocketLikely += 1;
      continue;
    }

    if (readingQualityScore(quality, batchAccuracyM) >= QUALITY_COMPOSITE_THRESHOLD) {
      counters.valid += 1;
    }
  }

  return counters;
}

/**
 * Calculate uptime (duration) in seconds from a summary object
 *
 * @param summary Summary object with period_start and period_end dates
 * @returns Uptime in seconds, or 0 if dates are invalid
 */
export function calculateUptimeSeconds(summary: Summary): number {
  const start = summary?.period_start ? summary.period_start.getTime() : 0;
  const end = summary?.period_end ? summary.period_end.getTime() : start;

  if (!start || !end) {
    return 0;
  }

  return Math.max(0, Math.floor((end - start) / 1000));
}

// ── WeatherXM Quality-of-Data checks (github.com/weatherxm-network/qod, README) ──

/**
 * QoD "suspicious jump" bound for pressure, ported from WeatherXM's code
 * (qod `initial_params.py`), not its README, which lists the 1-min-average
 * value (0.5) for raw data: 0.8 hPa for one raw step, growing 0.8 hPa per
 * minute of gap (their slower-station scaling), capped at the 15 hPa hourly
 * limit they take from the European Commission.
 *
 * Applied only between two stationary readings. Hydrostatic balance,
 * dp/dz = -ρg, gives ~0.12 hPa per metre, so a moving phone changes pressure by
 * climbing alone; a still one can only see the weather's tendency, which is
 * what the bound limits. The values themselves are empirical: no equation
 * fixes the largest real tendency.
 */
export const QOD_PRESSURE_JUMP_STEP_HPA = 0.8;
export const QOD_PRESSURE_JUMP_HPA_PER_MIN = 0.8;
export const QOD_PRESSURE_JUMP_CAP_HPA = 15;

/** Largest credible pressure change between two stationary readings [dtMs] apart. */
export function qodPressureJumpBound(dtMs: number): number {
  return Math.min(
    QOD_PRESSURE_JUMP_CAP_HPA,
    Math.max(QOD_PRESSURE_JUMP_STEP_HPA, QOD_PRESSURE_JUMP_HPA_PER_MIN * (dtMs / 60_000)),
  );
}

/** QoD constancy thresholds (WeatherXM QoD Table 6), in milliseconds. */
export const QOD_PRESSURE_CONSTANT_MS = 120 * 60_000;
export const QOD_LIGHT_CONSTANT_MS = 120 * 60_000;

type TimedReading = { t: Date; pressure?: number; light?: number; quality?: { motion_state?: string } };

/**
 * Pressure readings that pass the QoD jump check, in time order. A reading is
 * dropped when it differs by more than the jump bound from the previous kept
 * reading and both were taken while stationary.
 */
export function qodPressureSeries(readings: TimedReading[]): TimedReading[] {
  const seq = readings
    .filter(r => r.pressure !== undefined && Number.isFinite(r.pressure))
    .sort((a, b) => a.t.getTime() - b.t.getTime());
  const kept: TimedReading[] = [];
  for (const r of seq) {
    const prev = kept[kept.length - 1];
    const bothStill = prev?.quality?.motion_state === 'stationary' && r.quality?.motion_state === 'stationary';
    if (prev && bothStill &&
        Math.abs(r.pressure! - prev.pressure!) > qodPressureJumpBound(r.t.getTime() - prev.t.getTime())) continue;
    kept.push(r);
  }
  return kept;
}

/**
 * QoD constancy check: true when every value of [key] is identical over a span
 * of at least [minSpanMs]. For light, a constant 0 is excluded (darkness is a
 * legitimate constant; QoD flags only constant non-zero illuminance).
 */
export function qodFrozen(readings: TimedReading[], key: 'pressure' | 'light', minSpanMs: number): boolean {
  const seq = readings
    .filter(r => r[key] !== undefined && Number.isFinite(r[key]))
    .sort((a, b) => a.t.getTime() - b.t.getTime());
  if (seq.length < 2) return false;
  const span = seq[seq.length - 1].t.getTime() - seq[0].t.getTime();
  if (span < minSpanMs) return false;
  const first = seq[0][key]!;
  if (key === 'light' && first === 0) return false;
  return seq.every(r => r[key] === first);
}

// ── Cross-device buddy check (TITAN, Båserud et al. 2020) ──────────────────────

/** Neighbourhood: H3 res-6 cell, ~36 km², about TITAN's 3 km box. */
export const BUDDY_AREA_RES = 6;
/** TITAN's buddy check needs at least this many neighbours; fewer means "isolated". */
export const BUDDY_MIN_NEIGHBOURS = 4;
/** TITAN flags a value beyond this many standard deviations from its neighbours. */
export const BUDDY_SD_FACTOR = 2;
/**
 * Floor for the neighbours' spread: a phone barometer's relative accuracy is about
 * 0.12 hPa (Hintz et al. 2019; McNicholas & Mass), so tighter agreement is chance.
 */
export const BUDDY_MIN_SD_HPA = 0.12;

export type BuddyVerdict =
  | { status: 'isolated'; neighbours: number }
  | { status: 'pass' | 'fail'; neighbours: number; median: number; sd: number; deviation: number };

/**
 * Compares one device's value with other devices' values nearby. Spread is the
 * robust SD (1.4826 × MAD, the normal-consistent scale), so one bad neighbour
 * cannot widen the band. A "fail" usually means a per-device offset (1-2 hPa
 * between phones, Muralidharan et al. 2014), so it annotates rather than rejects.
 */
export function buddyCheck(value: number, neighbours: number[]): BuddyVerdict {
  const n = neighbours.length;
  if (n < BUDDY_MIN_NEIGHBOURS) return { status: 'isolated', neighbours: n };
  const median = medianOfNumbers(neighbours);
  const mad = medianOfNumbers(neighbours.map(v => Math.abs(v - median)));
  const sd = Math.max(1.4826 * mad, BUDDY_MIN_SD_HPA);
  const deviation = value - median;
  return {
    status: Math.abs(deviation) > BUDDY_SD_FACTOR * sd ? 'fail' : 'pass',
    neighbours: n, median, sd, deviation,
  };
}

function medianOfNumbers(values: number[]): number {
  const s = [...values].sort((a, b) => a - b);
  const mid = s.length >> 1;
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}
