/**
 * The aggregation job's functional core (Gary Bernhardt, "Boundaries" / "functional core,
 * imperative shell"): every function here is pure - given the same input it returns the same
 * output, touches no database, no network, no clock. `aggregator.ts` is the imperative shell: it
 * reads rows, fetches weather, calls these functions, and writes the result.
 *
 * The split exists so the actual math (bucketing, spatial blending, movement scoring, weather
 * anomaly) can be unit-tested directly - no mocked Pool, no mocked fetch - and so that
 * `aggregator.ts` only has to get the plumbing right.
 */
import { latLngToCell, gridDisk, cellToLatLng } from 'h3-js';
import { decodeGeohash } from '../utils/geo';
import { AGGREGATION_WINDOW_MINUTES, MOVEMENT_GRAVITY_BASELINE, MOVEMENT_THRESHOLD } from '../constants';
import { blendCell, CellEstimate, lagSemivariance, rangeVariance } from '../utils/spatialBlend';
import { weatherRegionKey, WeatherObservation } from '../utils/weatherService';

export type WindowKey = string;
export type DayKey = string;

export interface BatchRow {
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
}

export interface WindowAccumulator {
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
  /** Σ n_b·σ²_b over batches whose within-batch spread is estimable, and Σ n_b of those batches. */
  pressureNoiseNum: number;
  pressureNoiseN: number;
  batterySum: number;
  batterySamples: number;
  locationSamples: number;
  qualitySamples: number;
  qualityValidSamples: number;
  pocketLikelySamples: number;
}

export interface DayAccumulator {
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

/**
 * Typical absolute error of an uncalibrated phone barometer, as a 1-sigma
 * (hPa). Studies report ~±1 hPa per device, stable over time (NOAA, J. Atmos.
 * Oceanic Technol. 2018; Hintz et al., Meteorol. Appl. 2019). Averaging N
 * devices shrinks it by sqrt(N); per-model calibration (device_model) would
 * shrink it further.
 */
export const PHONE_BAROMETER_BIAS_HPA = 1.0;

/**
 * Uncertainty of a cell's mean pressure: within-batch noise over the readings
 * plus the per-device bias over the devices. What a model needs to weight
 * this observation against its own background.
 */
export function pressureSigmaHpa(noiseVar: number, readings: number, devices: number): number | null {
  if (readings <= 0 || devices <= 0) return null;
  return Math.sqrt(noiseVar / readings + (PHONE_BAROMETER_BIAS_HPA ** 2) / devices);
}

export interface WindowResult {
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
  pressureAnomalyHpa: number | null;
  /** 1-sigma uncertainty of avgPressure (hPa); see pressureSigmaHpa(). */
  pressureSigmaHpa: number | null;
  weatherTempC: number | null;
  movementScore: number;
  vibrationScore: number;
  batteryAvg: number | null;
  locationShare: number;
  qualitySamples: number;
  qualityValidRatio: number | null;
  pocketRatio: number | null;
}

// Per-reading scores

// Movement score: how much real motion a reading implies, 0–1.
//
// accel_rms arrives under two conventions depending on what the device exposed.
// ForegroundService prefers TYPE_LINEAR_ACCELERATION (gravity already removed,
// magnitude ~0 at rest) and falls back to TYPE_ACCELEROMETER (gravity included,
// magnitude ~9.81 at rest) - both land in the same field, so the convention has
// to be resolved here rather than assumed.
//
// Rule: evaluate both interpretations, keep whichever implies LESS motion. A
// resting reading is ~0 under one convention and ~9.81 under the other; each is
// correctly read as "still" by its own interpretation and as "extreme motion" by
// the wrong one, so the minimum always selects the right convention. Continuous,
// no cut-off, and no sensor-provenance tag needed on the payload.
//
// Assuming gravity unconditionally (the previous behaviour) inverted the score
// for every linear-acceleration reading: a motionless phone scored 1.0. That was
// 74% of stored rows.
export const movementScore = (accelRms: number): number => {
  const asLinear = Math.abs(accelRms);
  const asGravityInclusive = Math.abs(accelRms - MOVEMENT_GRAVITY_BASELINE);
  return Math.min(1, Math.max(0, Math.min(asLinear, asGravityInclusive) / MOVEMENT_THRESHOLD));
};

// Vibration/road roughness score: normalized accel std dev.
// 0 = smooth (stationary/glassy road), 1 = severe vibration (potholes/rough terrain).
// Threshold 5 m/s² std dev = full score - calibrated against walk vs rough driving data.
export const vibrationScore = (accelStdDev: number): number => Math.min(1, Math.max(0, accelStdDev / 5.0));

// Time helpers

export function truncateToWindow(date: Date, windowMs: number): Date {
  return new Date(Math.floor(date.getTime() / windowMs) * windowMs);
}

export function nextWindowStart(date: Date, windowMs: number): Date {
  return new Date(date.getTime() + windowMs);
}

export function dayStartUtc(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

function buildDayKey(windowStart: Date, geohash: string): DayKey {
  return `${dayStartUtc(windowStart).toISOString()}|${geohash}`;
}

function mergeSets<T>(target: Set<T>, source: Set<T>): Set<T> {
  for (const value of source) target.add(value);
  return target;
}

/** H3 res-9 cell for a row: prefer the pre-computed column, fall back to decoding the geohash. */
function resolveH3Index(geohash: string, precomputed: string | null): string | null {
  if (precomputed) return precomputed;
  const c = decodeGeohash(geohash);
  return c ? latLngToCell(c.lat, c.lon, 9) : null;
}

// Step 1: raw rows -> 5-minute window accumulators

/**
 * Folds raw batch rows into per-(window, geohash) accumulators. `upToExclusive` excludes the
 * current, still-partial window - a row landing in it is dropped so a window is only ever
 * aggregated once, when it has fully elapsed.
 */
export function accumulateWindows(
  rows: readonly BatchRow[],
  windowMs: number,
  upToExclusive: Date,
): Map<WindowKey, WindowAccumulator> {
  const windowBuckets = new Map<WindowKey, WindowAccumulator>();

  for (const row of rows) {
    const geohash = row.geohash ?? undefined;
    if (!geohash) continue;

    const summary = row.summary;
    const readingsCount = typeof summary?.count === 'number' ? summary.count : 0;
    if (readingsCount <= 0) continue;

    const periodEnd = summary?.period_end ? new Date(summary.period_end) : new Date(row.timestamp_utc);
    const windowStart = truncateToWindow(periodEnd, windowMs);
    if (windowStart >= upToExclusive) continue; // skip the partial current window
    const windowEnd = nextWindowStart(windowStart, windowMs);
    const windowKey = `${windowStart.toISOString()}|${geohash}`;

    const rowH3 = resolveH3Index(geohash, row.h3_res9);

    let acc = windowBuckets.get(windowKey);
    if (!acc) {
      acc = {
        windowStart, windowEnd, geohash, h3Index: rowH3,
        samples: 0, deviceIds: new Set<string>(),
        lightSum: 0, lightMin: Number.POSITIVE_INFINITY, lightMax: Number.NEGATIVE_INFINITY,
        accelRmsSum: 0, accelStdDevSum: 0, gyroRmsSum: 0,
        pressureSum: 0, pressureSamples: 0, pressureNoiseNum: 0, pressureNoiseN: 0,
        batterySum: 0, batterySamples: 0, locationSamples: 0,
        qualitySamples: 0, qualityValidSamples: 0, pocketLikelySamples: 0,
      };
      windowBuckets.set(windowKey, acc);
    } else if (!acc.h3Index && rowH3) {
      acc.h3Index = rowH3; // fill in if earlier rows in bucket lacked it
    }

    acc.samples += readingsCount;
    acc.deviceIds.add(row.device_hash);

    const lightAvg = summary?.light?.avg;
    if (typeof lightAvg === 'number') acc.lightSum += lightAvg * readingsCount;
    if (typeof summary?.light?.min === 'number') acc.lightMin = Math.min(acc.lightMin, summary.light.min);
    if (typeof summary?.light?.max === 'number') acc.lightMax = Math.max(acc.lightMax, summary.light.max);

    if (typeof summary?.accel_rms === 'number') acc.accelRmsSum += summary.accel_rms * readingsCount;
    if (typeof summary?.accel_std_dev === 'number') acc.accelStdDevSum += summary.accel_std_dev * readingsCount;
    if (typeof summary?.gyro_rms === 'number') acc.gyroRmsSum += summary.gyro_rms * readingsCount;

    const pressureAvg = summary?.pressure?.avg;
    if (typeof pressureAvg === 'number') {
      acc.pressureSum += pressureAvg * readingsCount;
      acc.pressureSamples += readingsCount;
      const pv = summary?.pressure ? rangeVariance(summary.pressure.min, summary.pressure.max, readingsCount) : null;
      if (pv !== null) {
        acc.pressureNoiseNum += readingsCount * pv;
        acc.pressureNoiseN += readingsCount;
      }
    }

    if (typeof row.battery_level === 'number' && row.battery_level >= 0) {
      acc.batterySum += row.battery_level;
      acc.batterySamples += 1;
    }
    if (row.has_location) acc.locationSamples += readingsCount;

    // Quality counters baked into summary at ingest time - no need to re-read batch.
    const qualityValid = summary?.quality_valid ?? 0;
    const qualityPocketLikely = summary?.quality_pocket_likely ?? 0;
    if (qualityValid > 0 || qualityPocketLikely > 0) {
      acc.qualitySamples += readingsCount;
      acc.qualityValidSamples += qualityValid;
      acc.pocketLikelySamples += qualityPocketLikely;
    }
  }

  return windowBuckets;
}

// Step 2: which weather lookups the window buckets need

export interface WeatherLookup {
  key: string;
  lat: number;
  lon: number;
  at: Date;
}

/** A window bucket's centroid: H3 cell center, or the geohash's if it has no H3 index. */
function centroidOf(bucket: Pick<WindowAccumulator, 'h3Index' | 'geohash'>): { lat: number; lon: number } | null {
  return bucket.h3Index
    ? { lat: cellToLatLng(bucket.h3Index)[0], lon: cellToLatLng(bucket.h3Index)[1] }
    : decodeGeohash(bucket.geohash);
}

/**
 * One {@link WeatherLookup} per DISTINCT {@link weatherRegionKey} the buckets need - never one
 * per bucket. Two buckets whose centroids round to the same region+hour already collapse to one
 * `getWeatherAt` call inside its own cache; computing this up front lets the imperative shell fire
 * that one call itself (concurrently with the others, see `aggregator.ts`) instead of discovering
 * the duplication one sequential await at a time.
 */
export function planWeatherLookups(windowBuckets: ReadonlyMap<WindowKey, WindowAccumulator>): WeatherLookup[] {
  const byKey = new Map<string, WeatherLookup>();
  for (const bucket of windowBuckets.values()) {
    const centroid = centroidOf(bucket);
    if (!centroid) continue;
    const key = weatherRegionKey(centroid.lat, centroid.lon, bucket.windowStart);
    if (!byKey.has(key)) byKey.set(key, { key, lat: centroid.lat, lon: centroid.lon, at: bucket.windowStart });
  }
  return [...byKey.values()];
}

// Step 3: window accumulators (+ fetched weather) -> window results

/**
 * `weatherByKey` must have one entry (possibly `null`, meaning the lookup failed) for every key
 * {@link planWeatherLookups} returned for these same buckets - a missing key is treated the same
 * as a failed lookup.
 */
export function computeWindowResults(
  windowBuckets: ReadonlyMap<WindowKey, WindowAccumulator>,
  weatherByKey: ReadonlyMap<string, WeatherObservation | null>,
): WindowResult[] {
  // Build H3-keyed lookup for ring-1 spatial smoothing (same run only, no DB query).
  const h3WindowIndex = new Map<string, WindowAccumulator>();
  for (const bucket of windowBuckets.values()) {
    if (bucket.h3Index) h3WindowIndex.set(`${bucket.windowStart.toISOString()}|${bucket.h3Index}`, bucket);
  }

  // Pressure as a cell estimate, or null when its sampling variance cannot be estimated
  // (then that cell neither informs the neighbour statistics nor gets blended).
  const pressureCell = (b: WindowAccumulator): CellEstimate | null =>
    b.pressureSamples > 0 && b.pressureNoiseN > 0
      ? { mean: b.pressureSum / b.pressureSamples, n: b.pressureSamples, noiseVar: b.pressureNoiseNum / b.pressureNoiseN }
      : null;
  const neighborsOf = (b: WindowAccumulator): WindowAccumulator[] =>
    b.h3Index
      ? gridDisk(b.h3Index, 1)
          .filter(h => h !== b.h3Index)
          .map(h => h3WindowIndex.get(`${b.windowStart.toISOString()}|${h}`))
          .filter((nb): nb is WindowAccumulator => nb !== undefined)
      : [];

  // How fast pressure changes from one cell to the next is measured from this run's own
  // adjacent pairs (semivariance at the neighbour lag). No pairs -> null -> nothing is blended.
  const pressurePairs: Array<[CellEstimate, CellEstimate]> = [];
  for (const bucket of windowBuckets.values()) {
    const own = pressureCell(bucket);
    if (!own || !bucket.h3Index) continue;
    for (const nb of neighborsOf(bucket)) {
      const other = pressureCell(nb);
      if (other && nb.h3Index && bucket.h3Index < nb.h3Index) pressurePairs.push([own, other]); // each pair once
    }
  }
  const pressureGamma = lagSemivariance(pressurePairs);

  const results: WindowResult[] = [];
  for (const bucket of windowBuckets.values()) {
    const samples = bucket.samples;
    if (samples === 0) continue;

    const avgLight = isFinite(bucket.lightSum) ? bucket.lightSum / samples : null;
    const lightMin = bucket.lightMin === Number.POSITIVE_INFINITY ? null : bucket.lightMin;
    const lightMax = bucket.lightMax === Number.NEGATIVE_INFINITY ? null : bucket.lightMax;
    const avgAccelRms = bucket.accelRmsSum / samples;
    const avgAccelStdDev = bucket.accelStdDevSum / samples;
    const avgGyroRms = bucket.gyroRmsSum / samples;
    const avgPressureRaw = bucket.pressureSamples > 0 ? bucket.pressureSum / bucket.pressureSamples : null;

    // Neighbour smoothing of pressure in the same 5-min window. Light stays raw on purpose:
    // it is heavy-tailed and changes within a single cell (indoor/outdoor, shade), and
    // simulation shows a linear-domain blend is several times WORSE than no blend there
    // (spatialBlend.test.ts).
    let avgPressure = avgPressureRaw;
    const ownPressure = pressureCell(bucket);
    if (ownPressure && pressureGamma !== null) {
      const neighborCells = neighborsOf(bucket).map(pressureCell).filter((c): c is CellEstimate => c !== null);
      avgPressure = blendCell(ownPressure, neighborCells, pressureGamma);
    }

    // Regional weather background for this cell/window. Powers two things:
    // - pressureAnomalyHpa: local pressure minus background, isolating local effects
    //   (tunnels, elevation, microclimate) from passing weather systems (Optimal
    //   Interpolation-style "observation minus background").
    // - weatherTempC: stored raw, since phones have no reliable ambient thermometer to
    //   difference against.
    let pressureAnomalyHpa: number | null = null;
    let weatherTempC: number | null = null;
    const centroid = centroidOf(bucket);
    if (centroid) {
      const weather = weatherByKey.get(weatherRegionKey(centroid.lat, centroid.lon, bucket.windowStart)) ?? null;
      weatherTempC = weather?.temperatureC ?? null;
      const baseline = weather?.surfacePressureHpa;
      if (avgPressure !== null && baseline != null) pressureAnomalyHpa = avgPressure - baseline;
    }

    const qualitySamples = bucket.qualitySamples;
    results.push({
      windowStart: bucket.windowStart,
      windowEnd: bucket.windowEnd,
      geohash: bucket.geohash,
      h3Index: bucket.h3Index,
      samplesCount: samples,
      deviceCount: bucket.deviceIds.size,
      avgLight, lightMin, lightMax,
      avgAccelRms, avgAccelStdDev, avgGyroRms,
      avgPressure, pressureAnomalyHpa, weatherTempC,
      pressureSigmaHpa: avgPressureRaw === null ? null : pressureSigmaHpa(
        bucket.pressureNoiseN > 0 ? bucket.pressureNoiseNum / bucket.pressureNoiseN : 0,
        bucket.pressureSamples,
        bucket.deviceIds.size,
      ),
      movementScore: movementScore(avgAccelRms),
      vibrationScore: vibrationScore(avgAccelStdDev),
      batteryAvg: bucket.batterySamples > 0 ? bucket.batterySum / bucket.batterySamples : null,
      locationShare: samples > 0 ? bucket.locationSamples / samples : 0,
      qualitySamples,
      qualityValidRatio: qualitySamples > 0 ? bucket.qualityValidSamples / qualitySamples : null,
      pocketRatio: qualitySamples > 0 ? bucket.pocketLikelySamples / qualitySamples : null,
    });
  }
  return results;
}

// Step 4: window accumulators -> daily accumulators

/**
 * Daily rollups use the windows' RAW sums (not the spatially-blended pressure from
 * {@link computeWindowResults}): daily is a coarser product than the 5-min table and has never
 * carried the neighbour blend. Unchanged from the pre-split behaviour.
 */
export function buildDayBuckets(windowBuckets: ReadonlyMap<WindowKey, WindowAccumulator>): Map<DayKey, DayAccumulator> {
  const dayBuckets = new Map<DayKey, DayAccumulator>();
  for (const bucket of windowBuckets.values()) {
    const dayKey = buildDayKey(bucket.windowStart, bucket.geohash);
    let acc = dayBuckets.get(dayKey);
    if (!acc) {
      acc = {
        day: dayStartUtc(bucket.windowStart), geohash: bucket.geohash, h3Index: bucket.h3Index,
        samples: 0, deviceIds: new Set<string>(),
        lightSum: 0, lightMin: Number.POSITIVE_INFINITY, lightMax: Number.NEGATIVE_INFINITY,
        accelRmsSum: 0, accelStdDevSum: 0, gyroRmsSum: 0,
        pressureSum: 0, pressureSamples: 0,
        batterySum: 0, batterySamples: 0, locationSamples: 0, deviceActiveMinutes: 0,
        qualitySamples: 0, qualityValidSamples: 0, pocketLikelySamples: 0,
      };
      dayBuckets.set(dayKey, acc);
    } else if (!acc.h3Index && bucket.h3Index) {
      acc.h3Index = bucket.h3Index;
    }

    acc.samples += bucket.samples;
    acc.deviceIds = mergeSets(acc.deviceIds, bucket.deviceIds);
    acc.lightSum += bucket.lightSum;
    if (bucket.lightMin !== Number.POSITIVE_INFINITY) acc.lightMin = Math.min(acc.lightMin, bucket.lightMin);
    if (bucket.lightMax !== Number.NEGATIVE_INFINITY) acc.lightMax = Math.max(acc.lightMax, bucket.lightMax);
    acc.accelRmsSum += bucket.accelRmsSum;
    acc.accelStdDevSum += bucket.accelStdDevSum;
    acc.gyroRmsSum += bucket.gyroRmsSum;
    acc.pressureSum += bucket.pressureSum;
    acc.pressureSamples += bucket.pressureSamples;
    acc.batterySum += bucket.batterySum;
    acc.batterySamples += bucket.batterySamples;
    acc.locationSamples += bucket.locationSamples;
    acc.deviceActiveMinutes += bucket.deviceIds.size * AGGREGATION_WINDOW_MINUTES;
    acc.qualitySamples += bucket.qualitySamples;
    acc.qualityValidSamples += bucket.qualityValidSamples;
    acc.pocketLikelySamples += bucket.pocketLikelySamples;
  }
  return dayBuckets;
}
