import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import type { Pool, PoolClient } from 'pg';
import { latLngToCell } from 'h3-js';
import { decompressPayload, UnsupportedEncodingError } from '../utils/compression';
import { verifyApiKey, hashDeviceId } from '../utils/security';
import { deviceOrFirebaseAuth } from '../middleware/auth';
import { getPool } from '../database';
import { UploadBatchSchema, UploadBatch, SensorReading, StoragePayload } from '../models/upload';
import { H3_RES_PERSONAL, H3_RES_GLOBAL } from '../constants';
import {
  vectorMagnitude,
  analyzeQuality,
  filterOutliersMad,
  calculateUptimeSeconds,
  Summary,
} from '../utils/sensor-analytics';
import {
  checkDeviceRateLimit,
  checkUserRateLimit,
  validateSensorRanges,
  checkGpsVelocity,
} from '../utils/uploadValidation';

function summarizeBatch(readings: SensorReading[]): Summary {
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
  const accelMagnitudes = filterOutliersMad(accelMagnitudesRaw);

  const gyroReadings = readings.filter(r => r.gyro !== undefined);
  const gyroMagnitudesRaw = gyroReadings.length > 0
    ? gyroReadings.map(r => vectorMagnitude(r.gyro!))
    : [];
  const gyroMagnitudes = filterOutliersMad(gyroMagnitudesRaw);

  const periodStart = new Date(Math.min(...readings.map(r => r.t.getTime())));
  const periodEnd = new Date(Math.max(...readings.map(r => r.t.getTime())));

  // Pressure — filter spikes (sensor glitches produce implausible hPa values)
  const pressureRaw = readings.filter(r => r.pressure !== undefined).map(r => r.pressure!);
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

  return {
    count: readings.length,
    period_start: periodStart,
    period_end: periodEnd,
    light: lightSummary,
    accel_rms: accelMagnitudes.length > 0
      ? accelMagnitudes.reduce((a, b) => a + b, 0) / accelMagnitudes.length
      : 0,
    gyro_rms: gyroMagnitudes.length > 0
      ? gyroMagnitudes.reduce((a, b) => a + b, 0) / gyroMagnitudes.length
      : 0,
    pressure: pressureSummary,
    magnetic_magnitude: magneticSummary,
  };
}

function buildStoragePayload(batch: UploadBatch): StoragePayload {
  const summary = summarizeBatch(batch.batch);

  const payload: StoragePayload = {
    timestamp: batch.timestamp,
    summary,
    batch: batch.batch,
  };

  if (batch.location) payload.location = batch.location;
  if (batch.geohash) payload.geohash = batch.geohash;
  if (batch.battery_level !== undefined) payload.battery_level = batch.battery_level;
  if (batch.is_charging !== undefined) payload.is_charging = batch.is_charging;

  return payload;
}

async function upsertUserStats(
  pool: Pool | PoolClient,
  deviceHash: string,
  summary: Summary,
  readings: SensorReading[],
  timestamp: Date,
  userId: string | null,
): Promise<void> {
  const totalSamples = summary?.count ?? readings.length;
  if (totalSamples <= 0) {
    return;
  }

  const quality = analyzeQuality(readings);
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
      quality.valid,
      quality.pocketLikely,
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

        // 1a. Rate limit per device: max 120 batches per sliding hour
        if (await checkDeviceRateLimit(pool, deviceHash)) {
          request.log.warn({ deviceHash, limitType: 'device', maxPerHour: 120 }, 'Upload rate limit exceeded');
          return reply.code(429).header('Retry-After', '3600').send({
            error: 'Too Many Requests',
            message: 'Upload rate limit exceeded. Max 120 batches per hour per device.',
          });
        }

        // 1b. Rate limit per user: max 300 batches/hour across all devices
        if (await checkUserRateLimit(pool, userId)) {
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

        // ─────────────────────────────────────────────────────────────────────

        // Build storage payload
        const sanitizedPayload = buildStoragePayload(batch);
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
            `INSERT INTO sensor_batches (device_hash, timestamp_utc, batch_json, user_id, h3_res9, h3_res8)
             VALUES ($1, $2, $3::jsonb, $4, $5, $6)
             ON CONFLICT (device_hash, timestamp_utc) DO NOTHING`,
            [deviceHash, batch.timestamp, payloadJson, userId, h3Res9, h3Res8],
          );
          insertRowCount = insertResult.rowCount ?? 0;

          if (insertRowCount > 0) {
            await upsertUserStats(client, deviceHash, sanitizedPayload.summary, batch.batch, batch.timestamp, userId);
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

        return reply.code(202).send({ accepted_records: readingsCount });
      } catch (error) {
        request.log.error({ err: error }, 'Upload error');
        return reply.code(500).send({ error: 'Internal Server Error', requestId: request.id });
      }
    }
  );
}
