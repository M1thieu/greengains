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
 * Returns the subset of values within `multiplier × MAD` of the median.
 * If fewer than 4 values are provided, or if MAD is 0 (all identical),
 * the original array is returned unchanged (no false positives on flat signals).
 *
 * Reference: openSenseMap outlierTransformer uses 3σ-equivalent MAD threshold.
 */
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

  const threshold = multiplier * mad;
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
  const exposureScore = pocket === 'unlikely' ? 1.0 : 0.5;

  return locScore * 0.45 + motionScore * 0.35 + exposureScore * 0.20;
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
