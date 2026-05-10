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
  accel_rms: number;
  gyro_rms: number;
  pressure?: { avg: number; min: number; max: number };
  magnetic_magnitude?: { avg: number; min: number; max: number };
  /** Std dev of raw accel magnitudes — high = rough surface / vibration. */
  accel_std_dev: number;
  /** Quality counters baked in at ingest so the aggregator never needs the raw batch array. */
  quality_valid: number;
  quality_pocket_likely: number;
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
export function analyzeQuality(readings: SensorReading[]): QualityCounters {
  const counters: QualityCounters = {
    total: 0,
    valid: 0,
    pocketLikely: 0,
  };

  // Guard against non-array input
  if (!Array.isArray(readings)) {
    return counters;
  }

  for (const reading of readings) {
    const quality = reading?.quality;
    if (!quality) continue;

    counters.total += 1;

    // Check pocket state first
    const pocket = String(quality.pocket ?? '').toLowerCase();
    if (pocket === 'likely') {
      counters.pocketLikely += 1;
      continue; // Skip further quality checks for pocket readings
    }

    // Check location and motion quality
    const locationQuality = String(quality.location_quality ?? '').toLowerCase();
    const motionState = String(quality.motion_state ?? '').toLowerCase();
    const motionConfidence =
      typeof quality.motion_confidence === 'number' ? quality.motion_confidence : 0;

    const locationOk = ['high', 'medium', 'low'].includes(locationQuality);
    const motionOk = motionState !== 'unknown' && motionConfidence >= MOTION_CONFIDENCE_THRESHOLD;

    // Valid if: good location OR good motion OR explicitly not in pocket
    if (locationOk || motionOk || pocket === 'unlikely') {
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
