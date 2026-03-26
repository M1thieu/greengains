/**
 * Sensor Analytics Utilities
 *
 * Shared functions for analyzing sensor data quality and calculating metrics.
 * Used by both upload route (real-time) and aggregation job (batch processing).
 */

import { SensorReading } from '../models/upload';

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
    const motionOk = motionState !== 'unknown' && motionConfidence >= 0.2;

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
