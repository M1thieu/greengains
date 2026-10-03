import * as Sentry from '@sentry/node';
import { PoolClient } from 'pg';
import { getPool } from '../database';
import { getWeatherAt, WeatherObservation } from '../utils/weatherService';
import { mapWithConcurrency } from '../utils/concurrency';
import {
  AGGREGATION_WINDOW_MINUTES,
  AGGREGATION_JOB_INTERVAL_MS,
  SENSOR_BATCH_RETENTION_DAYS,
} from '../constants';
import {
  accumulateWindows,
  buildDayBuckets,
  computeWindowResults,
  planWeatherLookups,
  truncateToWindow,
  nextWindowStart,
  movementScore,
  vibrationScore,
  BatchRow,
  DayAccumulator,
  DayKey,
  WindowResult,
} from './aggregationCore';

export { AGGREGATION_WINDOW_MINUTES };

const WINDOW_MS = AGGREGATION_WINDOW_MINUTES * 60 * 1000;

/**
 * Defensive cap on simultaneous outbound requests to Open-Meteo while fetching the weather
 * lookups a run's window buckets need (deduped by {@link planWeatherLookups} first, so this is
 * "how many distinct regions/hours at once", not "how many buckets"). An operational safety
 * value, not a statistical one - chosen to be comfortably polite to a third-party API, not tuned.
 */
const WEATHER_FETCH_CONCURRENCY = 8;

let aggregationTimer: NodeJS.Timeout | null = null;
let lastPurgeDate: string | null = null; // UTC date string — purge runs at most once per day

// A job that fails every minute and one that never ran look identical from outside - and the
// error only reaches Sentry. This makes the last outcome readable from /health.
const aggregationStatus = {
  runs: 0,
  failures: 0,
  lastRunAt: null as string | null,
  lastDurationMs: null as number | null,
  lastError: null as string | null,
};

export function getAggregationStatus() {
  return { ...aggregationStatus };
}

async function runTracked(): Promise<void> {
  const started = Date.now();
  aggregationStatus.runs++;
  try {
    await runAggregationJob();
    aggregationStatus.lastError = null;
  } catch (error) {
    aggregationStatus.failures++;
    aggregationStatus.lastError = error instanceof Error ? error.message.slice(0, 200) : 'unknown error';
    throw error;
  } finally {
    aggregationStatus.lastRunAt = new Date().toISOString();
    aggregationStatus.lastDurationMs = Date.now() - started;
  }
}

export async function startAggregationJob(): Promise<void> {
  // Run once immediately, then schedule interval
  await runTracked().catch((error) => {
    console.error('[aggregation] initial run failed:', { err: error });
    Sentry.captureException(error, { tags: { job: 'aggregation', phase: 'initial' } });
  });
  aggregationTimer = setInterval(() => {
    const start = Date.now();
    runTracked().catch((error) => {
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
    const minDate = truncateToWindow(new Date(minRes.rows[0].min), WINDOW_MS);
    fromWindowEnd = nextWindowStart(minDate, WINDOW_MS);
  }

  // process only fully elapsed windows
  const upToExclusive = truncateToWindow(new Date(), WINDOW_MS);
  if (!fromWindowEnd || fromWindowEnd >= upToExclusive) {
    return; // nothing new
  }

  // Select only the sub-fields the aggregator needs - avoids pulling the raw
  // batch readings array (often 80–95% of the payload) across the wire.
  const rows = await pool.query<BatchRow>(
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

  // Functional core: pure bucketing + weather-lookup planning (no I/O)
  const windowBuckets = accumulateWindows(rows.rows, WINDOW_MS, upToExclusive);
  if (windowBuckets.size === 0) {
    return;
  }

  // Imperative shell: fetch exactly the weather this run needs, once per distinct region+hour,
  // with bounded concurrency instead of one sequential `await` per window bucket (a run with many
  // active cells - routine multi-user traffic, or catching up a backlog after downtime - used to
  // serialize one network round-trip per bucket; see the request-coalescing note on
  // weatherRegionKey and the p-limit-style cap on WEATHER_FETCH_CONCURRENCY above). ────────────
  const weatherLookups = planWeatherLookups(windowBuckets);
  const weatherResults = await mapWithConcurrency(
    weatherLookups,
    WEATHER_FETCH_CONCURRENCY,
    (lookup) => getWeatherAt(lookup.lat, lookup.lon, lookup.at),
  );
  const weatherByKey = new Map<string, WeatherObservation | null>(
    weatherLookups.map((lookup, i) => [lookup.key, weatherResults[i]]),
  );

  // Back to the functional core: everything from here on is pure, given the fetched weather.
  const windowResults: WindowResult[] = computeWindowResults(windowBuckets, weatherByKey);
  const dayBuckets: Map<DayKey, DayAccumulator> = buildDayBuckets(windowBuckets);

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
      // Non-fatal - log and continue; will retry tomorrow
      console.error('[aggregation] daily purge failed', { err: purgeError });
    }
  }
}

async function upsertWindowResults(
  client: PoolClient,
  results: WindowResult[],
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
  const avgGyroRms = results.map(r => r.avgGyroRms);
  const avgPressures = results.map(r => r.avgPressure);
  const pressureAnomalies = results.map(r => r.pressureAnomalyHpa);
  const weatherTemps = results.map(r => r.weatherTempC);
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
      avg_gyro_rms, avg_pressure, pressure_anomaly_hpa, weather_temp_c, movement_score, vibration_score, battery_avg, location_share,
      quality_samples, quality_valid_ratio, quality_pocket_ratio
    )
    SELECT * FROM UNNEST(
      $1::timestamptz[], $2::timestamptz[], $3::text[], $4::text[],
      $5::int[], $6::int[], $7::double precision[], $8::double precision[],
      $9::double precision[], $10::double precision[], $11::double precision[],
      $12::double precision[], $13::double precision[], $14::double precision[],
      $15::double precision[], $16::double precision[], $17::double precision[], $18::double precision[], $19::bigint[], $20::double precision[], $21::double precision[]
    ) AS t(
      window_start, window_end, geohash, h3_index, samples_count, device_count,
      avg_light, avg_light_min, avg_light_max, avg_accel_rms,
      avg_gyro_rms, avg_pressure, pressure_anomaly_hpa, weather_temp_c, movement_score, vibration_score, battery_avg, location_share,
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
      pressure_anomaly_hpa = EXCLUDED.pressure_anomaly_hpa,
      weather_temp_c = EXCLUDED.weather_temp_c,
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
      avgAccelRms, avgGyroRms, avgPressures, pressureAnomalies, weatherTemps, movementScores, vibrationScores, batteryAvgs, locationShares,
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
