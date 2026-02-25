import type { Pool } from 'pg';
import type { UploadBatch } from '../models/upload';

// Max batches accepted per device per sliding hour window.
// ~1 batch every 30s for a full hour — generous for real usage, blocks burst bots.
const MAX_BATCHES_PER_HOUR = 120;

// Speed threshold for GPS velocity anomaly detection (m/s).
// 300 m/s ≈ 1080 km/h — above any road/rail vehicle, well below commercial aircraft.
const MAX_GPS_SPEED_MPS = 300;

// ─── Rate Limiting ────────────────────────────────────────────────────────────

/**
 * Returns true if the device has exceeded the hourly upload rate limit.
 *
 * Uses a sliding 1-hour window on `created_at` in sensor_batches.
 * Purely DB-based — no in-memory state, scales horizontally across instances.
 */
export async function checkDeviceRateLimit(pool: Pool, deviceHash: string): Promise<boolean> {
  const result = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count
       FROM sensor_batches
      WHERE device_hash = $1
        AND created_at > NOW() - INTERVAL '1 hour'`,
    [deviceHash],
  );
  const count = parseInt(result.rows[0]?.count ?? '0', 10);
  return count >= MAX_BATCHES_PER_HOUR;
}

// ─── Sensor Range Validation ──────────────────────────────────────────────────

const SENSOR_BOUNDS = {
  light:    { min: 0,    max: 130_000 }, // lux: pitch dark → direct sunlight
  pressure: { min: 870,  max: 1084 },    // hPa: Everest summit → Dead Sea (sea level extremes)
  accelMag: { min: 0,    max: 50 },      // m/s² vector magnitude — far above any real device use
  gyroMag:  { min: 0,    max: 20 },      // rad/s vector magnitude — beyond any phone rotation speed
  magMag:   { min: 0,    max: 2000 },    // µT magnitude — 4× Earth's strongest field
} as const;

function vecMag(v: number[]): number {
  return Math.sqrt(v.reduce((sum, x) => sum + x * x, 0));
}

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
      if (vecMag(r.accel) > SENSOR_BOUNDS.accelMag.max) return 'accel';
    }
    if (r.gyro !== undefined) {
      if (vecMag(r.gyro) > SENSOR_BOUNDS.gyroMag.max) return 'gyro';
    }
    if (r.magnetic !== undefined && r.magnetic.length === 4) {
      if (r.magnetic[3] > SENSOR_BOUNDS.magMag.max) return 'magnetic';
    }
  }
  return null;
}

// ─── GPS Velocity Check ───────────────────────────────────────────────────────

/** Haversine distance in metres between two lat/lon coordinates. */
function haversineMetres(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6_371_000;
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
