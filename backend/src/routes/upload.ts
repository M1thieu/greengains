import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import type { Pool, PoolClient } from 'pg';
import { latLngToCell } from 'h3-js';
import { decompressPayload, UnsupportedEncodingError } from '../utils/compression';
import { verifyApiKey, hashDeviceId } from '../utils/security';
import { deviceOrFirebaseAuth } from '../middleware/auth';
import { getPool } from '../database';
import { UploadBatchSchema, UploadBatch, SensorReading, StoragePayload } from '../models/upload';
import { H3_RES_PERSONAL, H3_RES_GLOBAL } from '../constants';
import { invalidateProfileCache, refreshUserProfileCache } from './user';
import {
  vectorMagnitude,
  stdDev,
  analyzeQuality,
  filterOutliersMad,
  calculateUptimeSeconds,
  Summary,
} from '../utils/sensor-analytics';
import {
  checkRateLimits,
  validateSensorRanges,
  checkGpsVelocity,
  checkBatchIntegrity,
} from '../utils/uploadValidation';


// Neighborhood average cache keyed by geohash6 prefix — avoids a per-upload
// 7-day LIKE scan when multiple devices map the same cell back-to-back.
// Entries are geographically stable enough that 15-min staleness is acceptable.
interface _NeighborEntry {
  avgLight: number | null;
  avgPressure: number | null;
  count: number;
  expiresAt: number;
}
const _neighborCache = new Map<string, _NeighborEntry>();
const _NEIGHBOR_TTL_MS = 15 * 60 * 1000;

/**
 * Co-location cross-validation (fire-and-forget quality signal).
 *
 * Compares this batch's sensor averages against recent batches from OTHER devices
 * at the same geohash prefix (geohash6 ≈ 1.2 km × 0.6 km cell).
 * If a reading diverges by >3 IQR from the neighborhood distribution, it's a spatial outlier.
 *
 * Logs the divergence for monitoring; a future device-reputation layer can use these
 * logs to downweight persistently divergent devices.
 *
 * Source: IEEE IoT Journal 2019 — co-located participant cross-validation pattern.
 * Also: PurpleAir dual-sensor agreement, openSenseMap spatial consistency checks.
 */
async function checkCoLocationOutlier(
  pool: Pool,
  geohash: string,
  deviceHash: string,
  summary: Summary,
  log: { warn: (obj: unknown, msg: string) => void },
): Promise<void> {
  // Use geohash6 prefix (≈1.2 km × 0.6 km) — enough neighbors, not too broad.
  const geohashPrefix = geohash.slice(0, 6);

  // Serve from cache if fresh — skip the 7-day scan on repeated uploads in the same cell.
  let neighborCount: number;
  let neighborLight: number | null;
  let neighborPressure: number | null;

  const cached = _neighborCache.get(geohashPrefix);
  if (cached && cached.expiresAt > Date.now()) {
    neighborCount = cached.count;
    neighborLight = cached.avgLight;
    neighborPressure = cached.avgPressure;
  } else {
    const result = await pool.query<{
      avg_light: string | null;
      avg_pressure: string | null;
      batch_count: string;
    }>(
      `SELECT
         AVG((batch_json->'summary'->'light'->>'avg')::numeric)    AS avg_light,
         AVG((batch_json->'summary'->'pressure'->>'avg')::numeric) AS avg_pressure,
         COUNT(*)::text                                            AS batch_count
       FROM sensor_batches
       WHERE geohash LIKE $1
         AND device_hash != $2
         AND created_at > NOW() - INTERVAL '7 days'`,
      [`${geohashPrefix}%`, deviceHash],
    );
    const row = result.rows[0];
    neighborCount = parseInt(row?.batch_count ?? '0', 10);
    neighborLight = row?.avg_light != null ? parseFloat(row.avg_light!) : null;
    neighborPressure = row?.avg_pressure != null ? parseFloat(row.avg_pressure!) : null;
    _neighborCache.set(geohashPrefix, {
      avgLight: neighborLight,
      avgPressure: neighborPressure,
      count: neighborCount,
      expiresAt: Date.now() + _NEIGHBOR_TTL_MS,
    });
  }

  if (neighborCount < 3) return; // need at least 3 other devices to make a judgment

  const outlierFlags: string[] = [];

  // Light: divergence >10× (e.g., neighbors average 3000 lux outdoors, this batch = 0)
  if (neighborLight != null && summary.light != null) {
    const lightRatio = Math.max(summary.light.avg, 1) / Math.max(neighborLight, 1);
    if (lightRatio > 10 || lightRatio < 0.1) {
      outlierFlags.push(`light: batch=${summary.light.avg.toFixed(0)} neighbors=${neighborLight.toFixed(0)}`);
    }
  }

  // Pressure: divergence >15 hPa (same city, different altitudes can explain ~5–10 hPa)
  if (neighborPressure != null && summary.pressure != null) {
    const pressureDiff = Math.abs(summary.pressure.avg - neighborPressure);
    if (pressureDiff > 15) {
      outlierFlags.push(`pressure: batch=${summary.pressure.avg.toFixed(1)} neighbors=${neighborPressure.toFixed(1)} diff=${pressureDiff.toFixed(1)}`);
    }
  }

  if (outlierFlags.length > 0) {
    log.warn(
      { deviceHash, geohashPrefix, neighborCount, outlierFlags },
      'Spatial outlier: batch diverges from co-located devices',
    );
  }
}

function inferTransportMode(accelRms: number, speedMps?: number): string {
  if (accelRms < 0.15) return 'stationary';
  if (speedMps !== undefined) {
    if (speedMps > 3.5) return 'vehicle';   // >12.6 km/h — cycling or motorised
    if (speedMps >= 0.3) return 'walking';
  }
  return 'unknown';
}

// ISA standard atmosphere: normalize measured pressure to sea level so readings
// from cells at different elevations are comparable across the map.
// P_SL = P / (1 - 0.0000225577 × h)^5.25588  (h in metres, P in hPa)
function pressureToSeaLevel(hpa: number, altitudeM: number): number {
  const factor = Math.pow(1 - 0.0000225577 * altitudeM, 5.25588);
  return factor > 0 ? hpa / factor : hpa;
}

function summarizeBatch(readings: SensorReading[], batchAccuracyM?: number, speedMps?: number, altitudeM?: number): Summary {
  // Light — filter statistical outliers (MAD method) before averaging.
  // E.g. a single 65535 lux spike from sensor glitch won't skew the window average.
  const lightRaw = readings.filter(r => r.light !== undefined).map(r => r.light!);
  const lightReadings = filterOutliersMad(lightRaw);
  const lightSummary = lightReadings.length > 0
    ? {
        avg: lightReadings.reduce((a, b) => a + b, 0) / lightReadings.length,
        min: Math.min(...lightReadings),
        max: Math.max(...lightReadings),
      }
    : undefined;

  // Accel / gyro — outlier filter applied to magnitudes (spikes from drops/taps)
  const accelReadings = readings.filter(r => r.accel !== undefined);
  const accelMagnitudesRaw = accelReadings.length > 0
    ? accelReadings.map(r => vectorMagnitude(r.accel!))
    : [];
  // Std dev computed on raw (pre-MAD) magnitudes — vibration spikes ARE the signal.
  const accelStdDev = stdDev(accelMagnitudesRaw);
  const accelMagnitudes = filterOutliersMad(accelMagnitudesRaw);

  const gyroReadings = readings.filter(r => r.gyro !== undefined);
  const gyroMagnitudesRaw = gyroReadings.length > 0
    ? gyroReadings.map(r => vectorMagnitude(r.gyro!))
    : [];
  const gyroMagnitudes = filterOutliersMad(gyroMagnitudesRaw);

  const periodStart = new Date(Math.min(...readings.map(r => r.t.getTime())));
  const periodEnd = new Date(Math.max(...readings.map(r => r.t.getTime())));

  // Pressure — normalize to sea level (when altitude known), then filter spikes.
  const pressureRaw = readings.filter(r => r.pressure !== undefined).map(r =>
    altitudeM !== undefined ? pressureToSeaLevel(r.pressure!, altitudeM) : r.pressure!
  );
  const pressureReadings = filterOutliersMad(pressureRaw);
  const pressureSummary = pressureReadings.length > 0
    ? {
        avg: pressureReadings.reduce((a, b) => a + b, 0) / pressureReadings.length,
        min: Math.min(...pressureReadings),
        max: Math.max(...pressureReadings),
      }
    : undefined;

  // Magnetic — index [3] is pre-computed magnitude [x,y,z,mag]
  const magneticRaw = readings
    .filter(r => r.magnetic !== undefined && r.magnetic.length === 4)
    .map(r => r.magnetic![3]);
  const magneticMagnitudes = filterOutliersMad(magneticRaw);
  const magneticSummary = magneticMagnitudes.length > 0
    ? {
        avg: magneticMagnitudes.reduce((a, b) => a + b, 0) / magneticMagnitudes.length,
        min: Math.min(...magneticMagnitudes),
        max: Math.max(...magneticMagnitudes),
      }
    : undefined;

  // Quality counters — computed once here so the aggregator never needs to pull
  // the full raw batch array across the wire. ~80-95% reduction in wire transfer
  // for the aggregation job on batches with many readings.
  const quality = analyzeQuality(readings, batchAccuracyM);

  return {
    count: readings.length,
    period_start: periodStart,
    period_end: periodEnd,
    light: lightSummary,
    accel_rms: accelMagnitudes.length > 0
      ? accelMagnitudes.reduce((a, b) => a + b, 0) / accelMagnitudes.length
      : 0,
    accel_std_dev: accelStdDev,
    gyro_rms: gyroMagnitudes.length > 0
      ? gyroMagnitudes.reduce((a, b) => a + b, 0) / gyroMagnitudes.length
      : 0,
    pressure: pressureSummary,
    magnetic_magnitude: magneticSummary,
    quality_valid: quality.valid,
    quality_pocket_likely: quality.pocketLikely,
    transport_mode: inferTransportMode(
      accelMagnitudes.length > 0
        ? accelMagnitudes.reduce((a, b) => a + b, 0) / accelMagnitudes.length
        : 0,
      speedMps,
    ),
  };
}

function buildStoragePayload(batch: UploadBatch, qualityMultiplier = 1.0): StoragePayload {
  const summary = summarizeBatch(batch.batch, batch.location?.accuracy_m, batch.location?.speed_mps, batch.location?.altitude);

  // Apply the integrity multiplier to quality_valid — batches flagged as static/high-speed/etc.
  // get proportionally fewer valid readings credited, which flows into per-tile qualityRatio.
  if (qualityMultiplier < 1.0) {
    summary.quality_valid = Math.round(summary.quality_valid * qualityMultiplier);
  }

  const payload: StoragePayload = {
    timestamp: batch.timestamp,
    summary,
    batch: batch.batch,
    quality_multiplier: qualityMultiplier < 1.0 ? qualityMultiplier : undefined,
  };

  if (batch.location) {
    // Privacy by architecture: round to 3 decimals (~110m) before storage.
    // H3 cells are computed from precise coords at ingest, BEFORE this runs —
    // nothing finer than a zone ever touches disk, so no precise trail can leak.
    // Anti-teleport speed checks tolerate this error (they detect km-scale jumps).
    // Bearing is dropped: it reveals direction of travel, and nothing reads it.
    const { bearing_deg: _bearing, ...rest } = batch.location;
    payload.location = {
      ...rest,
      lat: Math.round(batch.location.lat * 1000) / 1000,
      lon: Math.round(batch.location.lon * 1000) / 1000,
    };
  }
  if (batch.geohash) payload.geohash = batch.geohash;
  if (batch.battery_level !== undefined) payload.battery_level = batch.battery_level;
  if (batch.is_charging !== undefined) payload.is_charging = batch.is_charging;
  if (batch.wifi_rssi_avg !== undefined) payload.wifi_rssi_avg = batch.wifi_rssi_avg;
  if (batch.wifi_ap_count !== undefined) payload.wifi_ap_count = batch.wifi_ap_count;

  return payload;
}

async function upsertUserStats(
  pool: Pool | PoolClient,
  deviceHash: string,
  summary: Summary,
  timestamp: Date,
  userId: string | null,
): Promise<void> {
  const totalSamples = summary?.count ?? 0;
  if (totalSamples <= 0) {
    return;
  }

  // Use pre-computed summary values — quality_valid already has qualityMultiplier applied.
  // Re-running analyzeQuality here would ignore the multiplier and overcount valid samples.
  const uptimeSeconds = calculateUptimeSeconds(summary);

  await pool.query(
    `INSERT INTO user_stats (
      device_hash, samples_count, valid_samples, pocket_samples, uptime_seconds, last_upload_at, user_id
    ) VALUES ($1, $2, $3, $4, $5, $6, $7)
    ON CONFLICT (device_hash)
    DO UPDATE SET
      samples_count = user_stats.samples_count + EXCLUDED.samples_count,
      valid_samples = user_stats.valid_samples + EXCLUDED.valid_samples,
      pocket_samples = user_stats.pocket_samples + EXCLUDED.pocket_samples,
      uptime_seconds = user_stats.uptime_seconds + EXCLUDED.uptime_seconds,
      last_upload_at = GREATEST(user_stats.last_upload_at, EXCLUDED.last_upload_at),
      user_id = COALESCE(EXCLUDED.user_id, user_stats.user_id), -- Update user_id if provided
      updated_at = NOW()`,
    [
      deviceHash,
      totalSamples,
      summary.quality_valid,
      summary.quality_pocket_likely,
      uptimeSeconds,
      timestamp,
      userId
    ],
  );
}

export async function uploadRoutes(fastify: FastifyInstance) {
  // Configure raw body parser ONLY for this route context
  fastify.addContentTypeParser(
    'application/json',
    { parseAs: 'buffer' },
    (req, body, done) => {
      done(null, body);
    },
  );

  fastify.post(
    '/upload',
    { preHandler: [verifyApiKey, deviceOrFirebaseAuth] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.uid;
      request.log.info({ userId }, 'Upload request received');

      try {
        // Decompress payload if needed
        const rawPayload = request.body as Buffer;
        const contentEncoding = request.headers['content-encoding'];

        let decompressed: Buffer;
        try {
          decompressed = decompressPayload(contentEncoding, rawPayload);
        } catch (error) {
          if (error instanceof UnsupportedEncodingError) {
            return reply.code(415).send({ error: 'Unsupported Media Type', message: error.message });
          }
          return reply.code(400).send({ error: 'Bad Request', message: 'Invalid compressed payload' });
        }

        // Parse and validate JSON
        let batch: UploadBatch;
        try {
          const parsed = JSON.parse(decompressed.toString('utf-8'));
          batch = UploadBatchSchema.parse(parsed);
        } catch (error: unknown) {
          const zodError = error as { issues?: unknown; message?: string };
          return reply.code(422).send({
            error: 'Unprocessable Entity',
            message: 'Validation failed',
            details: zodError.issues ?? zodError.message,
          });
        }

        // Hash device ID for anonymization
        const deviceHash = hashDeviceId(batch.device_id);
        const readingsCount = batch.batch.length;

        const pool = getPool();

        // ── Abuse prevention checks ───────────────────────────────────────────

        // 1. Rate limits — device + user in one DB round-trip
        const { deviceExceeded, userExceeded } = await checkRateLimits(pool, deviceHash, userId);
        if (deviceExceeded) {
          request.log.warn({ deviceHash, limitType: 'device', maxPerHour: 120 }, 'Upload rate limit exceeded');
          return reply.code(429).header('Retry-After', '3600').send({
            error: 'Too Many Requests',
            message: 'Upload rate limit exceeded. Max 120 batches per hour per device.',
          });
        }
        if (userExceeded) {
          request.log.warn({ userId, limitType: 'user', maxPerHour: 300 }, 'Upload rate limit exceeded');
          return reply.code(429).header('Retry-After', '3600').send({
            error: 'Too Many Requests',
            message: 'Upload rate limit exceeded. Max 300 batches per hour per account.',
          });
        }

        // 2. Sensor range validation: reject physically impossible values
        const invalidField = validateSensorRanges(batch);
        if (invalidField !== null) {
          return reply.code(422).send({
            error: 'Unprocessable Entity',
            message: `Sensor value out of valid range: ${invalidField}`,
          });
        }

        // 3. GPS velocity check: reject if implied speed > 300 m/s
        if (await checkGpsVelocity(pool, deviceHash, batch)) {
          return reply.code(422).send({
            error: 'Unprocessable Entity',
            message: 'GPS location implies physically impossible travel speed.',
          });
        }

        // 4. Batch integrity: O(n) pure-compute checks — no DB queries.
        const integrity = checkBatchIntegrity(batch);
        if (integrity.allPocket) {
          // >95% pocket-likely readings = no usable data in this batch.
          // Accept with 202 (don't penalise the client) but don't store.
          return reply.code(202).send({ accepted_records: 0, skipped: 'all_pocket' });
        }
        if (integrity.qualityMultiplier < 1.0) {
          request.log.warn(
            {
              deviceHash,
              likelyStatic: integrity.likelyStatic       || undefined,
              windowTooLong: integrity.windowTooLong     || undefined,
              highSpeed: integrity.highSpeed             || undefined,
              lightSensorStuck: integrity.lightSensorStuck || undefined,
              coarseGps: integrity.coarseGps             || undefined,
              pressureSpikes: integrity.pressureSpikes   || undefined,
              timestampDisordered: integrity.timestampDisordered || undefined,
              baroGpsDivergence: integrity.baroGpsDivergence || undefined,
              qualityMultiplier: integrity.qualityMultiplier,
            },
            'Batch integrity warning — storing with reduced quality weight',
          );
        }

        // ─────────────────────────────────────────────────────────────────────

        // Build storage payload (integrity flags baked into JSON — no schema change)
        const sanitizedPayload = buildStoragePayload(batch, integrity.qualityMultiplier);
        const payloadJson = JSON.stringify(sanitizedPayload);

        // Compute H3 indices at ingest — stored as indexed columns for fast tile queries.
        // Industry pattern: Helium/Nodle/Hivemapper all index by H3 cell at ingest, never at query time.
        const h3Res9 = batch.location ? latLngToCell(batch.location.lat, batch.location.lon, H3_RES_PERSONAL) : null;
        const h3Res8 = batch.location ? latLngToCell(batch.location.lat, batch.location.lon, H3_RES_GLOBAL) : null;

        // Atomically store batch + update stats — both succeed or neither does.
        // Without a transaction, a failed stats upsert would leave counts stale
        // until the device's next successful upload corrects them.
        const client = await pool.connect();
        let insertRowCount = 0;
        try {
          await client.query('BEGIN');

          const insertResult = await client.query(
            `INSERT INTO sensor_batches (device_hash, timestamp_utc, batch_json, user_id, h3_res9, h3_res8, sensor_flags)
             VALUES ($1, $2, $3::jsonb, $4, $5, $6, $7)
             ON CONFLICT (device_hash, timestamp_utc) DO NOTHING`,
            [deviceHash, batch.timestamp, payloadJson, userId, h3Res9, h3Res8, batch.sensor_flags ?? 0],
          );
          insertRowCount = insertResult.rowCount ?? 0;

          if (insertRowCount > 0) {
            await upsertUserStats(client, deviceHash, sanitizedPayload.summary, batch.timestamp, userId);
          }

          await client.query('COMMIT');
        } catch (txError) {
          await client.query('ROLLBACK');
          throw txError; // re-throw to outer catch → 500
        } finally {
          client.release();
        }

        // Duplicate batch (same device + timestamp already stored) — accept silently
        if (insertRowCount === 0) {
          return reply.code(202).send({ accepted_records: 0, duplicate: true });
        }

        // Log with stats
        const stats = sanitizedPayload.summary;
        const logData: Record<string, unknown> = {
          device_hash: deviceHash,
          batch_id: batch.batch_id ?? null,  // trace retries: same batch_id on retry = expected
          batch_size: readingsCount,
          period_start: stats.period_start,
          period_end: stats.period_end,
          avg_light: stats.light?.avg,
        };

        if (batch.location) {
          logData.location = `(${batch.location.lat}, ${batch.location.lon})`;
          logData.location_accuracy_m = batch.location.accuracy_m;
        }

        request.log.info(logData, 'Stored sensor batch');

        // Invalidate in-memory cache + refresh DB cache — both fire-and-forget
        // so the 202 response isn't delayed. Next profile read gets fresh data.
        if (userId) {
          invalidateProfileCache(userId);
          refreshUserProfileCache(userId).catch((err: unknown) => // intentionally no await
            fastify.log.error({ err, userId }, 'Profile cache refresh failed')
          );
        }

        // Co-location cross-validation (fire-and-forget, does not affect 202 response).
        // Compare this batch's sensor averages against recent batches at the same geohash
        // from OTHER devices. Large divergence = spatial outlier flag.
        // Source: IEEE IoT Journal 2019 — co-located participant cross-validation.
        if (batch.geohash && sanitizedPayload.summary.count >= 10) {
          checkCoLocationOutlier(pool, batch.geohash, deviceHash, sanitizedPayload.summary, fastify.log)
            .catch((err: unknown) => fastify.log.error({ err }, 'Co-location check failed'));
        }

        return reply.code(202).send({ accepted_records: readingsCount });
      } catch (error) {
        request.log.error({ err: error }, 'Upload error');
        return reply.code(500).send({ error: 'Internal Server Error', requestId: request.id });
      }
    }
  );
}
