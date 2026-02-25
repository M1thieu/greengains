import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import type { Pool } from 'pg';
import { decompressPayload, UnsupportedEncodingError } from '../utils/compression';
import { verifyApiKey } from '../utils/security';
import { verifyFirebaseToken } from '../utils/firebase-auth';
import { hashDeviceId } from '../utils/security';
import { getPool } from '../database';
import { UploadBatchSchema, UploadBatch, SensorReading } from '../models/upload';
import {
  vectorMagnitude,
  analyzeQuality,
  calculateUptimeSeconds,
  Summary,
} from '../utils/sensor-analytics';
import {
  checkDeviceRateLimit,
  validateSensorRanges,
  checkGpsVelocity,
} from '../utils/uploadValidation';

function summarizeBatch(readings: SensorReading[]): Summary {
  // Handle optional light data
  const lightReadings = readings.filter(r => r.light !== undefined).map(r => r.light!);
  const lightSummary = lightReadings.length > 0
    ? {
        avg: lightReadings.reduce((a, b) => a + b, 0) / lightReadings.length,
        min: Math.min(...lightReadings),
        max: Math.max(...lightReadings),
      }
    : undefined;

  // Handle optional accel data
  const accelReadings = readings.filter(r => r.accel !== undefined);
  const accelMagnitudes = accelReadings.length > 0
    ? accelReadings.map(r => vectorMagnitude(r.accel!))
    : [];

  // Handle optional gyro data
  const gyroReadings = readings.filter(r => r.gyro !== undefined);
  const gyroMagnitudes = gyroReadings.length > 0
    ? gyroReadings.map(r => vectorMagnitude(r.gyro!))
    : [];

  const periodStart = new Date(Math.min(...readings.map(r => r.t.getTime())));
  const periodEnd = new Date(Math.max(...readings.map(r => r.t.getTime())));

  // Handle optional pressure data
  const pressureReadings = readings.filter(r => r.pressure !== undefined).map(r => r.pressure!);
  const pressureSummary = pressureReadings.length > 0
    ? {
        avg: pressureReadings.reduce((a, b) => a + b, 0) / pressureReadings.length,
        min: Math.min(...pressureReadings),
        max: Math.max(...pressureReadings),
      }
    : undefined;

  // Handle optional magnetic data — index [3] is pre-computed magnitude [x,y,z,mag]
  const magneticMagnitudes = readings
    .filter(r => r.magnetic !== undefined && r.magnetic.length === 4)
    .map(r => r.magnetic![3]);
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

function buildStoragePayload(batch: UploadBatch): any {
  const summary = summarizeBatch(batch.batch);

  const payload: any = {
    timestamp: batch.timestamp,
    summary,
    batch: batch.batch,
  };

  if (batch.location) {
    payload.location = batch.location;
  }

  if (batch.geohash) {
    payload.geohash = batch.geohash;
  }

  if (batch.battery_level !== undefined) {
    payload.battery_level = batch.battery_level;
  }

  if (batch.is_charging !== undefined) {
    payload.is_charging = batch.is_charging;
  }

  return payload;
}

async function upsertUserStats(
  pool: Pool,
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
    {
      preHandler: verifyApiKey,
    },
    async (request: FastifyRequest, reply: FastifyReply) => {
      // 1. Verify Auth (Device Secret OR Firebase Token)
      let userId: string | null = null;
      const deviceSecret = request.headers['x-device-secret'] as string;

      if (deviceSecret) {
        // Verify Device Secret
        try {
          const pool = getPool();
          const result = await pool.query(
            'SELECT user_id FROM device_secrets WHERE secret = $1',
            [deviceSecret]
          );
          if (result.rows.length > 0) {
            userId = result.rows[0].user_id;
            console.log(`Authenticated via Device Secret. User: ${userId}`);
            // Update last_used_at
            await pool.query(
              'UPDATE device_secrets SET last_used_at = NOW() WHERE secret = $1',
              [deviceSecret]
            );
          } else {
            console.warn('Invalid Device Secret provided');
            return reply.code(401).send({ error: 'Unauthorized', message: 'Invalid Device Secret' });
          }
        } catch (e) {
          console.error('Device Secret verification failed:', e);
          return reply.code(500).send({ error: 'Internal Server Error' });
        }
      } else {
        // Fallback to Firebase Token
        try {
          userId = await verifyFirebaseToken(request, reply);
        } catch (e) {
          console.warn('Auth check failed or missing:', e);
          // If the auth check sent a response (e.g. 401), stop here.
          if (reply.sent) return;
        }
      }

      console.log(`Upload request received. User: ${userId || 'Anonymous/Legacy'}`);

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
        } catch (error: any) {
          return reply.code(422).send({
            error: 'Unprocessable Entity',
            message: 'Validation failed',
            details: error.issues || error.message,
          });
        }

        // Hash device ID for anonymization
        const deviceHash = hashDeviceId(batch.device_id);
        const readingsCount = batch.batch.length;

        const pool = getPool();

        // ── Abuse prevention checks ───────────────────────────────────────────

        // 1. Rate limit: max 120 batches per device per sliding hour
        if (await checkDeviceRateLimit(pool, deviceHash)) {
          return reply.code(429).send({
            error: 'Too Many Requests',
            message: 'Upload rate limit exceeded. Max 120 batches per hour per device.',
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

        // Store in database — ON CONFLICT DO NOTHING deduplicates retried uploads
        const insertResult = await pool.query(
          `INSERT INTO sensor_batches (device_hash, timestamp_utc, batch_json, user_id)
           VALUES ($1, $2, $3::jsonb, $4)
           ON CONFLICT (device_hash, timestamp_utc) DO NOTHING`,
          [deviceHash, batch.timestamp, payloadJson, userId],
        );

        // Duplicate batch (same device + timestamp already stored) — accept silently
        if (insertResult.rowCount === 0) {
          return reply.code(202).send({ accepted_records: 0, duplicate: true });
        }
        await upsertUserStats(pool, deviceHash, sanitizedPayload.summary, batch.batch, batch.timestamp, userId);

        // Log with stats
        const stats = sanitizedPayload.summary;
        const logData: any = {
          device_hash: deviceHash,
          batch_size: readingsCount,
          period_start: stats.period_start,
          period_end: stats.period_end,
          avg_light: stats.light?.avg,
        };

        if (batch.location) {
          logData.location = `(${batch.location.lat}, ${batch.location.lon})`;
          logData.location_accuracy_m = batch.location.accuracy_m;
        }

        console.log('Stored sensor batch', logData);

        return reply.code(202).send({ accepted_records: readingsCount });
      } catch (error) {
        console.error('Upload error:', error);
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    }
  );
}
