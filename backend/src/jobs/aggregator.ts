import * as Sentry from '@sentry/node';
import { PoolClient } from 'pg';
import { latLngToCell, gridDisk } from 'h3-js';
import { getPool } from '../database';
import { decodeGeohash } from '../utils/geo';
import {
  AGGREGATION_WINDOW_MINUTES,
  AGGREGATION_JOB_INTERVAL_MS,
  MOVEMENT_GRAVITY_BASELINE,
  MOVEMENT_THRESHOLD,
  SENSOR_BATCH_RETENTION_DAYS,
} from '../constants';

export { AGGREGATION_WINDOW_MINUTES };

const WINDOW_MS = AGGREGATION_WINDOW_MINUTES * 60 * 1000;

// Movement score: deviation from gravitational baseline (phone at rest ≈ 9.81 m/s²).
// MOVEMENT_THRESHOLD m/s² above/below resting = full score of 1.0.
const movementScore = (accelRms: number) =>
  Math.min(1, Math.max(0, Math.abs(accelRms - MOVEMENT_GRAVITY_BASELINE) / MOVEMENT_THRESHOLD));

// Vibration/road roughness score: normalized accel std dev.
// 0 = smooth (stationary/glassy road), 1 = severe vibration (potholes/rough terrain).
// Threshold 5 m/s² std dev = full score — calibrated against walk vs rough driving data.
const vibrationScore = (accelStdDev: number) => Math.min(1, Math.max(0, accelStdDev / 5.0));

type WindowKey = string;
type DayKey = string;

interface WindowAccumulator {
  windowStart: Date;
  windowEnd: Date;
  geohash: string;
  h3Index: string | null; // H3 res-9 cell — derived from h3_res9 column or geohash decode
  samples: number;
  deviceIds: Set<string>;
  lightSum: number;
  lightMin: number;
  lightMax: number;
  accelRmsSum: number;
  accelStdDevSum: number;
  gyroRmsSum: number;
  pressureSum: number;
  pressureSamples: number;
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
  h3Index: string | null;
  samples: number;
  deviceIds: Set<string>;
  lightSum: number;
  lightMin: number;
  lightMax: number;
  accelRmsSum: number;
  accelStdDevSum: number;
  gyroRmsSum: number;
  pressureSum: number;
  pressureSamples: number;
  batterySum: number;
  batterySamples: number;
  locationSamples: number;
  deviceActiveMinutes: number;
  qualitySamples: number;
  qualityValidSamples: number;
  pocketLikelySamples: number;
}

let aggregationTimer: NodeJS.Timeout | null = null;
let lastPurgeDate: string | null = null; // UTC date string — purge runs at most once per day

export async function startAggregationJob(): Promise<void> {
  // Run once immediately, then schedule interval
  await runAggregationJob().catch((error) => {
    console.error('[aggregation] initial run failed:', { err: error });
    Sentry.captureException(error, { tags: { job: 'aggregation', phase: 'initial' } });
  });
  aggregationTimer = setInterval(() => {
    const start = Date.now();
    runAggregationJob().catch((error) => {
      const elapsedMs = Date.now() - start;
      console.error('[aggregation] scheduled run failed', { err: error, elapsedMs });
      Sentry.captureException(error, { tags: { job: 'aggregation', phase: 'scheduled' }, extra: { elapsedMs } });
    });
  }, AGGREGATION_JOB_INTERVAL_MS);
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

  // Select only the sub-fields the aggregator needs — avoids pulling the raw
  // batch readings array (often 80–95% of the payload) across the wire.
  const rows = await pool.query<{
    device_hash: string;
    timestamp_utc: Date;
    geohash: string | null;
    summary: {
      count: number;
      period_end: string;
      light?: { avg: number; min: number; max: number };
      accel_rms: number;
      accel_std_dev?: number;
      gyro_rms: number;
      pressure?: { avg: number; min: number; max: number };
      quality_valid?: number;
      quality_pocket_likely?: number;
    } | null;
    battery_level: number | null;
    has_location: boolean;
    h3_res9: string | null;
  }>(
    `SELECT
       device_hash,
       timestamp_utc,
       batch_json->>'geohash'                            AS geohash,
       batch_json->'summary'                             AS summary,
       (batch_json->>'battery_level')::float             AS battery_level,
       (batch_json->'location') IS NOT NULL              AS has_location,
       h3_res9
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
    const geohash: string | undefined = row.geohash ?? undefined;
    if (!geohash) {
      continue;
    }

    const summary = row.summary;
    const readingsCount: number = typeof summary?.count === 'number' ? summary.count : 0;
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

    // Resolve H3 index: prefer pre-computed column, fall back to geohash decode
    const rowH3 = row.h3_res9 ?? (() => {
      const c = decodeGeohash(geohash);
      return c ? latLngToCell(c.lat, c.lon, 9) : null;
    })();

    let windowAcc = windowBuckets.get(windowKey);
    if (!windowAcc) {
      windowAcc = {
        windowStart,
        windowEnd,
        geohash,
        h3Index: rowH3,
        samples: 0,
        deviceIds: new Set<string>(),
        lightSum: 0,
        lightMin: Number.POSITIVE_INFINITY,
        lightMax: Number.NEGATIVE_INFINITY,
        accelRmsSum: 0,
        accelStdDevSum: 0,
        gyroRmsSum: 0,
        pressureSum: 0,
        pressureSamples: 0,
        batterySum: 0,
        batterySamples: 0,
        locationSamples: 0,
        qualitySamples: 0,
        qualityValidSamples: 0,
        pocketLikelySamples: 0,
      };
      windowBuckets.set(windowKey, windowAcc);
    } else if (!windowAcc.h3Index && rowH3) {
      windowAcc.h3Index = rowH3; // fill in if earlier rows in bucket lacked it
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
    const accelStd = summary?.accel_std_dev;
    if (typeof accelStd === 'number') {
      windowAcc.accelStdDevSum += accelStd * readingsCount;
    }

    const gyroRms = summary?.gyro_rms;
    if (typeof gyroRms === 'number') {
      windowAcc.gyroRmsSum += gyroRms * readingsCount;
    }

    const pressureAvg = summary?.pressure?.avg;
    if (typeof pressureAvg === 'number') {
      windowAcc.pressureSum += pressureAvg * readingsCount;
      windowAcc.pressureSamples += readingsCount;
    }

    if (typeof row.battery_level === 'number' && row.battery_level >= 0) {
      windowAcc.batterySum += row.battery_level;
      windowAcc.batterySamples += 1;
    }

    if (row.has_location) {
      windowAcc.locationSamples += readingsCount;
    }

    // Quality counters baked into summary at ingest time — no need to re-read batch.
    const qualityValid       = summary?.quality_valid       ?? 0;
    const qualityPocketLikely = summary?.quality_pocket_likely ?? 0;
    if (qualityValid > 0 || qualityPocketLikely > 0) {
      windowAcc.qualitySamples       += readingsCount;
      windowAcc.qualityValidSamples  += qualityValid;
      windowAcc.pocketLikelySamples  += qualityPocketLikely;
    }
  }

  if (windowBuckets.size === 0) {
    return;
  }

  // Build H3-keyed lookup for ring-1 spatial smoothing (same window only, no DB query).
  const h3WindowIndex = new Map<string, WindowAccumulator>();
  for (const bucket of windowBuckets.values()) {
    if (bucket.h3Index) {
      h3WindowIndex.set(`${bucket.windowStart.toISOString()}|${bucket.h3Index}`, bucket);
    }
  }

  const windowResults = [];
  for (const bucket of windowBuckets.values()) {
    const samples = bucket.samples;
    if (samples === 0) {
      continue;
    }
    const deviceCount = bucket.deviceIds.size;
    const avgLightRaw =
      samples > 0 && isFinite(bucket.lightSum) ? bucket.lightSum / samples : null;
    const lightMin = bucket.lightMin === Number.POSITIVE_INFINITY ? null : bucket.lightMin;
    const lightMax = bucket.lightMax === Number.NEGATIVE_INFINITY ? null : bucket.lightMax;
    const avgAccelRms = bucket.accelRmsSum / samples;
    const avgAccelStdDev = bucket.accelStdDevSum / samples;
    const avgGyroRms = bucket.gyroRmsSum / samples;
    const avgPressureRaw = bucket.pressureSamples > 0 ? bucket.pressureSum / bucket.pressureSamples : null;

    // Ring-1 spatial smoothing: blend this cell 80% with the average of present neighbors 20%.
    // Only considers neighbors present in the same 5-min window — no DB queries, no latency.
    let avgLight = avgLightRaw;
    let avgPressure = avgPressureRaw;
    if (bucket.h3Index) {
      const neighborBuckets = gridDisk(bucket.h3Index, 1)
        .filter(h => h !== bucket.h3Index)
        .map(h => h3WindowIndex.get(`${bucket.windowStart.toISOString()}|${h}`))
        .filter((b): b is WindowAccumulator => b !== undefined);
      if (neighborBuckets.length > 0) {
        if (avgLightRaw !== null) {
          const neighborLights = neighborBuckets
            .map(nb => nb.samples > 0 && isFinite(nb.lightSum) ? nb.lightSum / nb.samples : null)
            .filter((v): v is number => v !== null);
          if (neighborLights.length > 0) {
            const neighborAvg = neighborLights.reduce((a, b) => a + b, 0) / neighborLights.length;
            avgLight = avgLightRaw * 0.8 + neighborAvg * 0.2;
          }
        }
        if (avgPressureRaw !== null) {
          const neighborPressures = neighborBuckets
            .map(nb => nb.pressureSamples > 0 ? nb.pressureSum / nb.pressureSamples : null)
            .filter((v): v is number => v !== null);
          if (neighborPressures.length > 0) {
            const neighborAvg = neighborPressures.reduce((a, b) => a + b, 0) / neighborPressures.length;
            avgPressure = avgPressureRaw * 0.8 + neighborAvg * 0.2;
          }
        }
      }
    }
    const windowMovementScore = movementScore(avgAccelRms);
    const windowVibrationScore = vibrationScore(avgAccelStdDev);
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
      h3Index: bucket.h3Index,
      samplesCount: samples,
      deviceCount,
      avgLight,
      lightMin,
      lightMax,
      avgAccelRms,
      avgAccelStdDev,
      avgGyroRms,
      avgPressure,
      movementScore: windowMovementScore,
      vibrationScore: windowVibrationScore,
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
        h3Index: bucket.h3Index,
        samples: 0,
        deviceIds: new Set<string>(),
        lightSum: 0,
        lightMin: Number.POSITIVE_INFINITY,
        lightMax: Number.NEGATIVE_INFINITY,
        accelRmsSum: 0,
        accelStdDevSum: 0,
        gyroRmsSum: 0,
        pressureSum: 0,
        pressureSamples: 0,
        batterySum: 0,
        batterySamples: 0,
        locationSamples: 0,
        deviceActiveMinutes: 0,
        qualitySamples: 0,
        qualityValidSamples: 0,
        pocketLikelySamples: 0,
      };
      dayBuckets.set(dayKey, dayAcc);
    } else if (!dayAcc.h3Index && bucket.h3Index) {
      dayAcc.h3Index = bucket.h3Index;
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
    dayAcc.accelStdDevSum += bucket.accelStdDevSum;
    dayAcc.gyroRmsSum += bucket.gyroRmsSum;
    dayAcc.pressureSum += bucket.pressureSum;
    dayAcc.pressureSamples += bucket.pressureSamples;
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
    console.log(`[aggregation] committed ${windowResults.length} windows, ${dayBuckets.size} day buckets`);
  } catch (error) {
    console.error('[aggregation] transaction rolled back', {
      err: error,
      windowCount: windowResults.length,
      dayCount: dayBuckets.size,
    });
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }

  // Purge old raw batches once per UTC day (aggregated data is kept indefinitely).
  const todayUtc = new Date().toISOString().slice(0, 10);
  if (lastPurgeDate !== todayUtc) {
    lastPurgeDate = todayUtc;
    try {
      const purgeResult = await pool.query(
        `DELETE FROM sensor_batches
         WHERE timestamp_utc < NOW() - INTERVAL '${SENSOR_BATCH_RETENTION_DAYS} days'`,
      );
      if ((purgeResult.rowCount ?? 0) > 0) {
        console.log(`[aggregation] purged ${purgeResult.rowCount} raw batches older than ${SENSOR_BATCH_RETENTION_DAYS} days`);
      }
    } catch (purgeError) {
      // Non-fatal — log and continue; will retry tomorrow
      console.error('[aggregation] daily purge failed', { err: purgeError });
    }
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
    h3Index: string | null;
    samplesCount: number;
    deviceCount: number;
    avgLight: number | null;
    lightMin: number | null;
    lightMax: number | null;
    avgAccelRms: number;
    avgAccelStdDev: number;
    avgGyroRms: number;
    avgPressure: number | null;
    movementScore: number;
    vibrationScore: number;
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
  const h3Indexes = results.map(r => r.h3Index);
  const samplesCounts = results.map(r => r.samplesCount);
  const deviceCounts = results.map(r => r.deviceCount);
  const avgLights = results.map(r => r.avgLight);
  const lightMins = results.map(r => r.lightMin);
  const lightMaxes = results.map(r => r.lightMax);
  const avgAccelRms = results.map(r => r.avgAccelRms);
  const avgAccelStdDevs = results.map(r => r.avgAccelStdDev);
  const avgGyroRms = results.map(r => r.avgGyroRms);
  const avgPressures = results.map(r => r.avgPressure);
  const movementScores = results.map(r => r.movementScore);
  const vibrationScores = results.map(r => r.vibrationScore);
  const batteryAvgs = results.map(r => r.batteryAvg);
  const locationShares = results.map(r => r.locationShare);
  const qualitySampleCounts = results.map(r => r.qualitySamples);
  const qualityValidRatios = results.map(r => r.qualityValidRatio);
  const pocketRatios = results.map(r => r.pocketRatio);

  await client.query(
    `INSERT INTO sensor_aggregates_5m (
      window_start, window_end, geohash, h3_index, samples_count, device_count,
      avg_light, avg_light_min, avg_light_max, avg_accel_rms,
      avg_gyro_rms, avg_pressure, movement_score, vibration_score, battery_avg, location_share,
      quality_samples, quality_valid_ratio, quality_pocket_ratio
    )
    SELECT * FROM UNNEST(
      $1::timestamptz[], $2::timestamptz[], $3::text[], $4::text[],
      $5::int[], $6::int[], $7::double precision[], $8::double precision[],
      $9::double precision[], $10::double precision[], $11::double precision[],
      $12::double precision[], $13::double precision[], $14::double precision[],
      $15::double precision[], $16::double precision[], $17::bigint[], $18::double precision[], $19::double precision[]
    ) AS t(
      window_start, window_end, geohash, h3_index, samples_count, device_count,
      avg_light, avg_light_min, avg_light_max, avg_accel_rms,
      avg_gyro_rms, avg_pressure, movement_score, vibration_score, battery_avg, location_share,
      quality_samples, quality_valid_ratio, quality_pocket_ratio
    )
    ON CONFLICT (window_start, geohash)
    DO UPDATE SET
      h3_index     = COALESCE(EXCLUDED.h3_index, sensor_aggregates_5m.h3_index),
      samples_count = EXCLUDED.samples_count,
      device_count = EXCLUDED.device_count,
      avg_light = EXCLUDED.avg_light,
      avg_light_min = EXCLUDED.avg_light_min,
      avg_light_max = EXCLUDED.avg_light_max,
      avg_accel_rms = EXCLUDED.avg_accel_rms,
      avg_gyro_rms = EXCLUDED.avg_gyro_rms,
      avg_pressure = EXCLUDED.avg_pressure,
      movement_score = EXCLUDED.movement_score,
      vibration_score = EXCLUDED.vibration_score,
      battery_avg = EXCLUDED.battery_avg,
      location_share = EXCLUDED.location_share,
      quality_samples = EXCLUDED.quality_samples,
      quality_valid_ratio = EXCLUDED.quality_valid_ratio,
      quality_pocket_ratio = EXCLUDED.quality_pocket_ratio,
      updated_at = NOW()`,
    [
      windowStarts, windowEnds, geohashes, h3Indexes, samplesCounts,
      deviceCounts, avgLights, lightMins, lightMaxes,
      avgAccelRms, avgGyroRms, avgPressures, movementScores, vibrationScores, batteryAvgs, locationShares,
      qualitySampleCounts, qualityValidRatios, pocketRatios
    ],
  );
}

async function upsertDailyResults(
  client: PoolClient,
  dayBuckets: Map<DayKey, DayAccumulator>,
): Promise<void> {
  if (dayBuckets.size === 0) return;

  // Prepare arrays for bulk insert
  const days: string[] = [];
  const geohashes: string[] = [];
  const h3Indexes: (string | null)[] = [];
  const samplesCounts: number[] = [];
  const deviceCounts: number[] = [];
  const avgLights: (number | null)[] = [];
  const lightMins: (number | null)[] = [];
  const lightMaxes: (number | null)[] = [];
  const avgAccelRms: number[] = [];
  const avgGyroRms: number[] = [];
  const avgPressures: (number | null)[] = [];
  const movementScores: number[] = [];
  const vibrationScores: number[] = [];
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
    const accelStd = bucket.accelStdDevSum / samples;
    const gyroRms = bucket.gyroRmsSum / samples;
    const avgPressure = bucket.pressureSamples > 0 ? bucket.pressureSum / bucket.pressureSamples : null;
    const dayMovementScore = movementScore(accelRms);
    const dayVibrationScore = vibrationScore(accelStd);
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
    h3Indexes.push(bucket.h3Index);
    samplesCounts.push(samples);
    deviceCounts.push(deviceCount);
    avgLights.push(avgLight);
    lightMins.push(lightMin);
    lightMaxes.push(lightMax);
    avgAccelRms.push(accelRms);
    avgGyroRms.push(gyroRms);
    avgPressures.push(avgPressure);
    movementScores.push(dayMovementScore);
    vibrationScores.push(dayVibrationScore);
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
      day, geohash, h3_index, samples_count, device_count,
      avg_light, avg_light_min, avg_light_max, avg_accel_rms,
      avg_gyro_rms, avg_pressure, movement_score, vibration_score, battery_avg, location_share,
      device_hours, quality_samples, quality_valid_ratio, quality_pocket_ratio
    )
    SELECT * FROM UNNEST(
      $1::date[], $2::text[], $3::text[], $4::bigint[], $5::int[],
      $6::double precision[], $7::double precision[], $8::double precision[],
      $9::double precision[], $10::double precision[], $11::double precision[],
      $12::double precision[], $13::double precision[], $14::double precision[],
      $15::double precision[], $16::double precision[], $17::bigint[], $18::double precision[], $19::double precision[]
    ) AS t(
      day, geohash, h3_index, samples_count, device_count,
      avg_light, avg_light_min, avg_light_max, avg_accel_rms,
      avg_gyro_rms, avg_pressure, movement_score, vibration_score, battery_avg, location_share,
      device_hours, quality_samples, quality_valid_ratio, quality_pocket_ratio
    )
    ON CONFLICT (day, geohash)
    DO UPDATE SET
      h3_index     = COALESCE(EXCLUDED.h3_index, sensor_aggregates_daily.h3_index),
      samples_count = EXCLUDED.samples_count,
      device_count = EXCLUDED.device_count,
      avg_light = EXCLUDED.avg_light,
      avg_light_min = EXCLUDED.avg_light_min,
      avg_light_max = EXCLUDED.avg_light_max,
      avg_accel_rms = EXCLUDED.avg_accel_rms,
      avg_gyro_rms = EXCLUDED.avg_gyro_rms,
      avg_pressure = EXCLUDED.avg_pressure,
      movement_score = EXCLUDED.movement_score,
      vibration_score = EXCLUDED.vibration_score,
      battery_avg = EXCLUDED.battery_avg,
      location_share = EXCLUDED.location_share,
      device_hours = EXCLUDED.device_hours,
      quality_samples = EXCLUDED.quality_samples,
      quality_valid_ratio = EXCLUDED.quality_valid_ratio,
      quality_pocket_ratio = EXCLUDED.quality_pocket_ratio,
      updated_at = NOW()`,
    [
      days, geohashes, h3Indexes, samplesCounts, deviceCounts,
      avgLights, lightMins, lightMaxes, avgAccelRms,
      avgGyroRms, avgPressures, movementScores, vibrationScores, batteryAvgs, locationShares,
      deviceHours, qualitySampleCounts, qualityValidRatios, pocketRatios
    ],
  );
}
