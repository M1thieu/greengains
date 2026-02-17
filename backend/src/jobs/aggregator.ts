import { PoolClient } from 'pg';
import { getPool } from '../database';
import { analyzeQuality, QualityCounters } from '../utils/sensor-analytics';

export const AGGREGATION_WINDOW_MINUTES = 5;
const WINDOW_MS = AGGREGATION_WINDOW_MINUTES * 60 * 1000;
const JOB_INTERVAL_MS = 60 * 1000; // run once a minute

type WindowKey = string;
type DayKey = string;

interface WindowAccumulator {
  windowStart: Date;
  windowEnd: Date;
  geohash: string;
  samples: number;
  deviceIds: Set<string>;
  lightSum: number;
  lightMin: number;
  lightMax: number;
  accelRmsSum: number;
  gyroRmsSum: number;
  batterySum: number;
  batterySamples: number;
  locationSamples: number;
  qualitySamples: number;
  qualityValidSamples: number;
  pocketLikelySamples: number;
}

interface DayAccumulator {
  day: Date;
  geohash: string;
  samples: number;
  deviceIds: Set<string>;
  lightSum: number;
  lightMin: number;
  lightMax: number;
  accelRmsSum: number;
  gyroRmsSum: number;
  batterySum: number;
  batterySamples: number;
  locationSamples: number;
  deviceActiveMinutes: number;
  qualitySamples: number;
  qualityValidSamples: number;
  pocketLikelySamples: number;
}

let aggregationTimer: NodeJS.Timeout | null = null;

export async function startAggregationJob(): Promise<void> {
  // Run once immediately, then schedule interval
  await runAggregationJob().catch((error) =>
    console.error('[aggregation] initial run failed:', error),
  );
  aggregationTimer = setInterval(() => {
    runAggregationJob().catch((error) =>
      console.error('[aggregation] scheduled run failed:', error),
    );
  }, JOB_INTERVAL_MS);
}

export async function stopAggregationJob(): Promise<void> {
  if (aggregationTimer) {
    clearInterval(aggregationTimer);
    aggregationTimer = null;
  }
}

function truncateToWindow(date: Date): Date {
  const ms = date.getTime();
  return new Date(Math.floor(ms / WINDOW_MS) * WINDOW_MS);
}

function nextWindowStart(date: Date): Date {
  return new Date(date.getTime() + WINDOW_MS);
}

function dayStartUtc(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

export async function runAggregationJob(): Promise<void> {
  const pool = getPool();

  const existingMaxRes = await pool.query<{ max: Date | null }>(
    'SELECT MAX(window_end) AS max FROM sensor_aggregates_5m',
  );

  let fromWindowEnd: Date | null = existingMaxRes.rows[0]?.max ?? null;
  if (!fromWindowEnd) {
    // No aggregates yet; start from earliest batch
    const minRes = await pool.query<{ min: Date | null }>(
      'SELECT MIN(timestamp_utc) AS min FROM sensor_batches',
    );
    if (!minRes.rows[0]?.min) {
      return; // nothing to aggregate
    }
    const minDate = truncateToWindow(new Date(minRes.rows[0].min));
    fromWindowEnd = nextWindowStart(minDate);
  }

  // process only fully elapsed windows
  const upToExclusive = truncateToWindow(new Date());
  if (!fromWindowEnd || fromWindowEnd >= upToExclusive) {
    return; // nothing new
  }

  const rows = await pool.query<{
    device_hash: string;
    timestamp_utc: Date;
    batch_json: any;
  }>(
    `SELECT device_hash, timestamp_utc, batch_json
     FROM sensor_batches
     WHERE timestamp_utc > $1 AND timestamp_utc <= $2
     ORDER BY timestamp_utc ASC`,
    [fromWindowEnd.toISOString(), upToExclusive.toISOString()],
  );

  if (rows.rowCount === 0) {
    return;
  }

  const windowBuckets = new Map<WindowKey, WindowAccumulator>();
  const dayBuckets = new Map<DayKey, DayAccumulator>();

  for (const row of rows.rows) {
    const payload = typeof row.batch_json === 'string' ? JSON.parse(row.batch_json) : row.batch_json;
    const geohash: string | undefined = payload?.geohash;
    if (!geohash) {
      continue;
    }

    const summary = payload?.summary;
    const readingsCount: number =
      typeof summary?.count === 'number'
        ? summary.count
        : Array.isArray(payload?.batch)
        ? payload.batch.length
        : 0;
    if (readingsCount <= 0) {
      continue;
    }

    const periodEnd = summary?.period_end ? new Date(summary.period_end) : new Date(row.timestamp_utc);
    const windowStart = truncateToWindow(periodEnd);
    if (windowStart >= upToExclusive) {
      continue; // skip partial current window
    }
    const windowEnd = nextWindowStart(windowStart);
    const windowKey = `${windowStart.toISOString()}|${geohash}`;

    let windowAcc = windowBuckets.get(windowKey);
    if (!windowAcc) {
      windowAcc = {
        windowStart,
        windowEnd,
        geohash,
        samples: 0,
        deviceIds: new Set<string>(),
        lightSum: 0,
        lightMin: Number.POSITIVE_INFINITY,
        lightMax: Number.NEGATIVE_INFINITY,
        accelRmsSum: 0,
        gyroRmsSum: 0,
        batterySum: 0,
        batterySamples: 0,
        locationSamples: 0,
        qualitySamples: 0,
        qualityValidSamples: 0,
        pocketLikelySamples: 0,
      };
      windowBuckets.set(windowKey, windowAcc);
    }

    windowAcc.samples += readingsCount;
    windowAcc.deviceIds.add(row.device_hash);

    const lightAvg = summary?.light?.avg;
    const lightMin = summary?.light?.min;
    const lightMax = summary?.light?.max;
    if (typeof lightAvg === 'number') {
      windowAcc.lightSum += lightAvg * readingsCount;
    }
    if (typeof lightMin === 'number') {
      windowAcc.lightMin = Math.min(windowAcc.lightMin, lightMin);
    }
    if (typeof lightMax === 'number') {
      windowAcc.lightMax = Math.max(windowAcc.lightMax, lightMax);
    }

    const accelRms = summary?.accel_rms;
    if (typeof accelRms === 'number') {
      windowAcc.accelRmsSum += accelRms * readingsCount;
    }

    const gyroRms = summary?.gyro_rms;
    if (typeof gyroRms === 'number') {
      windowAcc.gyroRmsSum += gyroRms * readingsCount;
    }

    const batteryLevel = payload?.battery_level;
    if (typeof batteryLevel === 'number' && batteryLevel >= 0) {
      windowAcc.batterySum += batteryLevel;
      windowAcc.batterySamples += 1;
    }

    if (payload?.location != null) {
      windowAcc.locationSamples += readingsCount;
    }

    if (Array.isArray(payload?.batch)) {
      const qualityCounters = analyzeQuality(payload.batch);
      windowAcc.qualitySamples += qualityCounters.total;
      windowAcc.qualityValidSamples += qualityCounters.valid;
      windowAcc.pocketLikelySamples += qualityCounters.pocketLikely;
    }
  }

  if (windowBuckets.size === 0) {
    return;
  }

  const windowResults = [];
  for (const bucket of windowBuckets.values()) {
    const samples = bucket.samples;
    if (samples === 0) {
      continue;
    }
    const deviceCount = bucket.deviceIds.size;
    const avgLight =
      samples > 0 && isFinite(bucket.lightSum) ? bucket.lightSum / samples : null;
    const lightMin = bucket.lightMin === Number.POSITIVE_INFINITY ? null : bucket.lightMin;
    const lightMax = bucket.lightMax === Number.NEGATIVE_INFINITY ? null : bucket.lightMax;
    const avgAccelRms = bucket.accelRmsSum / samples;
    const avgGyroRms = bucket.gyroRmsSum / samples;
    const movementScore = Math.min(1, Math.max(0, avgAccelRms / 9.81));
    const batteryAvg =
      bucket.batterySamples > 0 ? bucket.batterySum / bucket.batterySamples : null;
    const locationShare = samples > 0 ? bucket.locationSamples / samples : 0;
    const qualitySamples = bucket.qualitySamples;
    const qualityValidRatio =
      qualitySamples > 0 ? bucket.qualityValidSamples / qualitySamples : null;
    const pocketRatio =
      qualitySamples > 0 ? bucket.pocketLikelySamples / qualitySamples : null;

    windowResults.push({
      windowStart: bucket.windowStart,
      windowEnd: bucket.windowEnd,
      geohash: bucket.geohash,
      samplesCount: samples,
      deviceCount,
      avgLight,
      lightMin,
      lightMax,
      avgAccelRms,
      avgGyroRms,
      movementScore,
      batteryAvg,
      locationShare,
      qualitySamples,
      qualityValidRatio,
      pocketRatio,
    });

    const dayKey = buildDayKey(bucket.windowStart, bucket.geohash);
    let dayAcc = dayBuckets.get(dayKey);
    if (!dayAcc) {
      const dayStart = dayStartUtc(bucket.windowStart);
      dayAcc = {
        day: dayStart,
        geohash: bucket.geohash,
        samples: 0,
        deviceIds: new Set<string>(),
        lightSum: 0,
        lightMin: Number.POSITIVE_INFINITY,
        lightMax: Number.NEGATIVE_INFINITY,
        accelRmsSum: 0,
        gyroRmsSum: 0,
        batterySum: 0,
        batterySamples: 0,
        locationSamples: 0,
        deviceActiveMinutes: 0,
        qualitySamples: 0,
        qualityValidSamples: 0,
        pocketLikelySamples: 0,
      };
      dayBuckets.set(dayKey, dayAcc);
    }

    dayAcc.samples += samples;
    dayAcc.deviceIds = mergeSets(dayAcc.deviceIds, bucket.deviceIds);
    dayAcc.lightSum += bucket.lightSum;
    if (bucket.lightMin !== Number.POSITIVE_INFINITY) {
      dayAcc.lightMin = Math.min(dayAcc.lightMin, bucket.lightMin);
    }
    if (bucket.lightMax !== Number.NEGATIVE_INFINITY) {
      dayAcc.lightMax = Math.max(dayAcc.lightMax, bucket.lightMax);
    }
    dayAcc.accelRmsSum += bucket.accelRmsSum;
    dayAcc.gyroRmsSum += bucket.gyroRmsSum;
    dayAcc.batterySum += bucket.batterySum;
    dayAcc.batterySamples += bucket.batterySamples;
    dayAcc.locationSamples += bucket.locationSamples;
    dayAcc.deviceActiveMinutes += deviceCount * AGGREGATION_WINDOW_MINUTES;
    dayAcc.qualitySamples += bucket.qualitySamples;
    dayAcc.qualityValidSamples += bucket.qualityValidSamples;
    dayAcc.pocketLikelySamples += bucket.pocketLikelySamples;
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await upsertWindowResults(client, windowResults);
    await upsertDailyResults(client, dayBuckets);
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

function mergeSets<T>(target: Set<T>, source: Set<T>): Set<T> {
  for (const value of source) {
    target.add(value);
  }
  return target;
}

function buildDayKey(windowStart: Date, geohash: string): DayKey {
  const day = dayStartUtc(windowStart);
  return `${day.toISOString()}|${geohash}`;
}

async function upsertWindowResults(
  client: PoolClient,
  results: Array<{
    windowStart: Date;
    windowEnd: Date;
    geohash: string;
    samplesCount: number;
    deviceCount: number;
    avgLight: number | null;
    lightMin: number | null;
    lightMax: number | null;
    avgAccelRms: number;
    avgGyroRms: number;
    movementScore: number;
    batteryAvg: number | null;
    locationShare: number;
    qualitySamples: number;
    qualityValidRatio: number | null;
    pocketRatio: number | null;
  }>,
): Promise<void> {
  if (results.length === 0) return;

  // Bulk insert using UNNEST - 10-50x faster than N+1 pattern
  const windowStarts = results.map(r => r.windowStart.toISOString());
  const windowEnds = results.map(r => r.windowEnd.toISOString());
  const geohashes = results.map(r => r.geohash);
  const samplesCounts = results.map(r => r.samplesCount);
  const deviceCounts = results.map(r => r.deviceCount);
  const avgLights = results.map(r => r.avgLight);
  const lightMins = results.map(r => r.lightMin);
  const lightMaxes = results.map(r => r.lightMax);
  const avgAccelRms = results.map(r => r.avgAccelRms);
  const avgGyroRms = results.map(r => r.avgGyroRms);
  const movementScores = results.map(r => r.movementScore);
  const batteryAvgs = results.map(r => r.batteryAvg);
  const locationShares = results.map(r => r.locationShare);
  const qualitySampleCounts = results.map(r => r.qualitySamples);
  const qualityValidRatios = results.map(r => r.qualityValidRatio);
  const pocketRatios = results.map(r => r.pocketRatio);

  await client.query(
    `INSERT INTO sensor_aggregates_5m (
      window_start, window_end, geohash, samples_count, device_count,
      avg_light, avg_light_min, avg_light_max, avg_accel_rms,
      avg_gyro_rms, movement_score, battery_avg, location_share,
      quality_samples, quality_valid_ratio, quality_pocket_ratio
    )
    SELECT * FROM UNNEST(
      $1::timestamptz[], $2::timestamptz[], $3::text[],
      $4::int[], $5::int[], $6::double precision[], $7::double precision[],
      $8::double precision[], $9::double precision[], $10::double precision[],
      $11::double precision[], $12::double precision[], $13::double precision[],
      $14::bigint[], $15::double precision[], $16::double precision[]
    ) AS t(
      window_start, window_end, geohash, samples_count, device_count,
      avg_light, avg_light_min, avg_light_max, avg_accel_rms,
      avg_gyro_rms, movement_score, battery_avg, location_share,
      quality_samples, quality_valid_ratio, quality_pocket_ratio
    )
    ON CONFLICT (window_start, geohash)
    DO UPDATE SET
      samples_count = EXCLUDED.samples_count,
      device_count = EXCLUDED.device_count,
      avg_light = EXCLUDED.avg_light,
      avg_light_min = EXCLUDED.avg_light_min,
      avg_light_max = EXCLUDED.avg_light_max,
      avg_accel_rms = EXCLUDED.avg_accel_rms,
      avg_gyro_rms = EXCLUDED.avg_gyro_rms,
      movement_score = EXCLUDED.movement_score,
      battery_avg = EXCLUDED.battery_avg,
      location_share = EXCLUDED.location_share,
      quality_samples = EXCLUDED.quality_samples,
      quality_valid_ratio = EXCLUDED.quality_valid_ratio,
      quality_pocket_ratio = EXCLUDED.quality_pocket_ratio,
      updated_at = NOW()`,
    [
      windowStarts, windowEnds, geohashes, samplesCounts,
      deviceCounts, avgLights, lightMins, lightMaxes,
      avgAccelRms, avgGyroRms, movementScores, batteryAvgs, locationShares,
      qualitySampleCounts, qualityValidRatios, pocketRatios
    ],
  );
}

async function upsertDailyResults(
  client: PoolClient,
  dayBuckets: Map<
    DayKey,
    {
      day: Date;
      geohash: string;
      samples: number;
      deviceIds: Set<string>;
      lightSum: number;
      lightMin: number;
      lightMax: number;
      accelRmsSum: number;
      gyroRmsSum: number;
      batterySum: number;
      batterySamples: number;
      locationSamples: number;
      deviceActiveMinutes: number;
      qualitySamples: number;
      qualityValidSamples: number;
      pocketLikelySamples: number;
    }
  >,
): Promise<void> {
  if (dayBuckets.size === 0) return;

  // Prepare arrays for bulk insert
  const days: string[] = [];
  const geohashes: string[] = [];
  const samplesCounts: number[] = [];
  const deviceCounts: number[] = [];
  const avgLights: (number | null)[] = [];
  const lightMins: (number | null)[] = [];
  const lightMaxes: (number | null)[] = [];
  const avgAccelRms: number[] = [];
  const avgGyroRms: number[] = [];
  const movementScores: number[] = [];
  const batteryAvgs: (number | null)[] = [];
  const locationShares: number[] = [];
  const deviceHours: number[] = [];
  const qualitySampleCounts: number[] = [];
  const qualityValidRatios: (number | null)[] = [];
  const pocketRatios: (number | null)[] = [];

  for (const bucket of dayBuckets.values()) {
    const samples = bucket.samples;
    if (samples === 0) continue;

    const deviceCount = bucket.deviceIds.size;
    const avgLight =
      samples > 0 && isFinite(bucket.lightSum) ? bucket.lightSum / samples : null;
    const lightMin =
      bucket.lightMin === Number.POSITIVE_INFINITY ? null : bucket.lightMin;
    const lightMax =
      bucket.lightMax === Number.NEGATIVE_INFINITY ? null : bucket.lightMax;
    const accelRms = bucket.accelRmsSum / samples;
    const gyroRms = bucket.gyroRmsSum / samples;
    const movementScore = Math.min(1, Math.max(0, accelRms / 9.81));
    const batteryAvg =
      bucket.batterySamples > 0 ? bucket.batterySum / bucket.batterySamples : null;
    const locationShare = samples > 0 ? bucket.locationSamples / samples : 0;
    const deviceHour = bucket.deviceActiveMinutes / 60;
    const qualitySamples = bucket.qualitySamples;
    const qualityValidRatio =
      qualitySamples > 0 ? bucket.qualityValidSamples / qualitySamples : null;
    const pocketRatio =
      qualitySamples > 0 ? bucket.pocketLikelySamples / qualitySamples : null;

    days.push(bucket.day.toISOString().slice(0, 10));
    geohashes.push(bucket.geohash);
    samplesCounts.push(samples);
    deviceCounts.push(deviceCount);
    avgLights.push(avgLight);
    lightMins.push(lightMin);
    lightMaxes.push(lightMax);
    avgAccelRms.push(accelRms);
    avgGyroRms.push(gyroRms);
    movementScores.push(movementScore);
    batteryAvgs.push(batteryAvg);
    locationShares.push(locationShare);
    deviceHours.push(deviceHour);
    qualitySampleCounts.push(qualitySamples);
    qualityValidRatios.push(qualityValidRatio);
    pocketRatios.push(pocketRatio);
  }

  if (days.length === 0) return;

  // Bulk insert using UNNEST - 10-50x faster than N+1 pattern
  await client.query(
    `INSERT INTO sensor_aggregates_daily (
      day, geohash, samples_count, device_count,
      avg_light, avg_light_min, avg_light_max, avg_accel_rms,
      avg_gyro_rms, movement_score, battery_avg, location_share,
      device_hours, quality_samples, quality_valid_ratio, quality_pocket_ratio
    )
    SELECT * FROM UNNEST(
      $1::date[], $2::text[], $3::bigint[], $4::int[],
      $5::double precision[], $6::double precision[], $7::double precision[],
      $8::double precision[], $9::double precision[], $10::double precision[],
      $11::double precision[], $12::double precision[], $13::double precision[],
      $14::bigint[], $15::double precision[], $16::double precision[]
    ) AS t(
      day, geohash, samples_count, device_count,
      avg_light, avg_light_min, avg_light_max, avg_accel_rms,
      avg_gyro_rms, movement_score, battery_avg, location_share,
      device_hours, quality_samples, quality_valid_ratio, quality_pocket_ratio
    )
    ON CONFLICT (day, geohash)
    DO UPDATE SET
      samples_count = EXCLUDED.samples_count,
      device_count = EXCLUDED.device_count,
      avg_light = EXCLUDED.avg_light,
      avg_light_min = EXCLUDED.avg_light_min,
      avg_light_max = EXCLUDED.avg_light_max,
      avg_accel_rms = EXCLUDED.avg_accel_rms,
      avg_gyro_rms = EXCLUDED.avg_gyro_rms,
      movement_score = EXCLUDED.movement_score,
      battery_avg = EXCLUDED.battery_avg,
      location_share = EXCLUDED.location_share,
      device_hours = EXCLUDED.device_hours,
      quality_samples = EXCLUDED.quality_samples,
      quality_valid_ratio = EXCLUDED.quality_valid_ratio,
      quality_pocket_ratio = EXCLUDED.quality_pocket_ratio,
      updated_at = NOW()`,
    [
      days, geohashes, samplesCounts, deviceCounts,
      avgLights, lightMins, lightMaxes, avgAccelRms,
      avgGyroRms, movementScores, batteryAvgs, locationShares,
      deviceHours, qualitySampleCounts, qualityValidRatios, pocketRatios
    ],
  );
}
