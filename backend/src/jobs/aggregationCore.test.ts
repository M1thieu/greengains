import test from 'node:test';
import assert from 'node:assert/strict';
import { latLngToCell } from 'h3-js';
import {
  accumulateWindows, buildDayBuckets, computeWindowResults, planWeatherLookups, pressureSigmaHpa,
  movementScore, vibrationScore, truncateToWindow, nextWindowStart,
  BatchRow, WindowAccumulator,
} from './aggregationCore';
import { weatherRegionKey, WeatherObservation } from '../utils/weatherService';

const WINDOW_MS = 5 * 60 * 1000;
const T0 = new Date('2026-06-01T12:00:00Z').getTime();
const UP_TO = new Date('2026-06-01T13:00:00Z');

function row(overrides: Partial<BatchRow> & { t: number }): BatchRow {
  return {
    device_hash: 'd1',
    timestamp_utc: new Date(overrides.t),
    geohash: 'u09tv',
    summary: { count: 1, period_end: new Date(overrides.t).toISOString(), accel_rms: 0, gyro_rms: 0 },
    battery_level: null,
    has_location: false,
    h3_res9: null,
    ...overrides,
  };
}

// movementScore / vibrationScore: pure, no data needed

test('movementScore is 0 at rest under either sensor convention', () => {
  assert.equal(movementScore(0), 0);      // TYPE_LINEAR_ACCELERATION at rest
  assert.equal(movementScore(9.81), 0);   // TYPE_ACCELEROMETER at rest (gravity included)
});

test('movementScore saturates at 1 for a large deviation from either convention', () => {
  assert.equal(movementScore(100), 1);
});

test('vibrationScore is 0 for a perfectly smooth signal and clamps at 1', () => {
  assert.equal(vibrationScore(0), 0);
  assert.equal(vibrationScore(50), 1);
});

// truncateToWindow / nextWindowStart

test('truncateToWindow floors to the window boundary, nextWindowStart advances by exactly one window', () => {
  const mid = new Date(T0 + 137_000);
  const start = truncateToWindow(mid, WINDOW_MS);
  assert.equal(start.getTime(), T0);
  assert.equal(nextWindowStart(start, WINDOW_MS).getTime(), T0 + WINDOW_MS);
});

// accumulateWindows

test('two readings in the same window and geohash accumulate into one bucket', () => {
  const rows = [
    row({ t: T0 + 10_000, summary: { count: 2, period_end: new Date(T0 + 10_000).toISOString(), accel_rms: 1, gyro_rms: 0.5, light: { avg: 100, min: 90, max: 110 } } }),
    row({ t: T0 + 200_000, summary: { count: 3, period_end: new Date(T0 + 200_000).toISOString(), accel_rms: 3, gyro_rms: 1.5, light: { avg: 200, min: 150, max: 250 } } }),
  ];
  const buckets = accumulateWindows(rows, WINDOW_MS, UP_TO);
  assert.equal(buckets.size, 1);
  const b = [...buckets.values()][0];
  assert.equal(b.samples, 5); // 2 + 3
  // weighted: (100*2 + 200*3) / 5 = 160
  assert.equal(b.lightSum / b.samples, 160);
  assert.equal(b.lightMin, 90);
  assert.equal(b.lightMax, 250);
});

test('a row without a geohash is dropped, not crashed on', () => {
  const buckets = accumulateWindows([row({ t: T0, geohash: null })], WINDOW_MS, UP_TO);
  assert.equal(buckets.size, 0);
});

test('a row with count <= 0 is dropped', () => {
  const buckets = accumulateWindows(
    [row({ t: T0, summary: { count: 0, period_end: new Date(T0).toISOString(), accel_rms: 0, gyro_rms: 0 } })],
    WINDOW_MS, UP_TO,
  );
  assert.equal(buckets.size, 0);
});

test('a row landing in the still-open current window is excluded', () => {
  const buckets = accumulateWindows(
    [row({ t: UP_TO.getTime() + 1000, summary: { count: 1, period_end: new Date(UP_TO.getTime() + 1000).toISOString(), accel_rms: 0, gyro_rms: 0 } })],
    WINDOW_MS, UP_TO,
  );
  assert.equal(buckets.size, 0);
});

test('different geohashes in the same window make separate buckets', () => {
  const buckets = accumulateWindows(
    [row({ t: T0, geohash: 'u09tv' }), row({ t: T0, geohash: 'u09tw' })],
    WINDOW_MS, UP_TO,
  );
  assert.equal(buckets.size, 2);
});

test('h3_res9 column is preferred over decoding the geohash', () => {
  const buckets = accumulateWindows([row({ t: T0, h3_res9: 'deadbeef' })], WINDOW_MS, UP_TO);
  assert.equal([...buckets.values()][0].h3Index, 'deadbeef');
});

test('a later row can still fill in a missing h3Index for an existing bucket', () => {
  // '!!!' is truthy (kept) but invalid base32, so decodeGeohash fails and the first row
  // genuinely leaves h3Index null - unlike '', which accumulateWindows would drop outright.
  const buckets = accumulateWindows(
    [row({ t: T0, geohash: '!!!', h3_res9: null }), row({ t: T0 + 1000, geohash: '!!!', h3_res9: 'deadbeef' })],
    WINDOW_MS, UP_TO,
  );
  assert.equal([...buckets.values()][0].h3Index, 'deadbeef');
});

// buildDayBuckets

function makeWindowAcc(overrides: Partial<WindowAccumulator>): WindowAccumulator {
  return {
    windowStart: new Date(T0), windowEnd: new Date(T0 + WINDOW_MS), geohash: 'u09tv', h3Index: null,
    samples: 1, deviceIds: new Set(['d1']),
    lightSum: 10, lightMin: 10, lightMax: 10,
    accelRmsSum: 1, accelStdDevSum: 0.1, gyroRmsSum: 0.5,
    pressureSum: 1013, pressureSamples: 1, pressureNoiseNum: 0, pressureNoiseN: 0,
    batterySum: 80, batterySamples: 1, locationSamples: 1,
    qualitySamples: 1, qualityValidSamples: 1, pocketLikelySamples: 0,
    ...overrides,
  };
}

test('two windows on the same UTC day and geohash roll into one day bucket', () => {
  const windows = new Map([
    ['w1', makeWindowAcc({ windowStart: new Date('2026-06-01T00:05:00Z'), samples: 2, deviceIds: new Set(['a']) })],
    ['w2', makeWindowAcc({ windowStart: new Date('2026-06-01T23:55:00Z'), samples: 3, deviceIds: new Set(['b']) })],
  ]);
  const days = buildDayBuckets(windows);
  assert.equal(days.size, 1);
  const d = [...days.values()][0];
  assert.equal(d.samples, 5);
  assert.equal(d.deviceIds.size, 2); // union of device sets, not overwritten
  assert.equal(d.day.toISOString(), '2026-06-01T00:00:00.000Z');
});

test('windows on different UTC days make separate day buckets', () => {
  const windows = new Map([
    ['w1', makeWindowAcc({ windowStart: new Date('2026-06-01T23:58:00Z') })],
    ['w2', makeWindowAcc({ windowStart: new Date('2026-06-02T00:02:00Z') })],
  ]);
  assert.equal(buildDayBuckets(windows).size, 2);
});

test('daily rollup uses RAW pressure, not the spatially blended per-window value (documented, unchanged behaviour)', () => {
  const windows = new Map([['w1', makeWindowAcc({ pressureSum: 2000, pressureSamples: 2 })]]);
  const days = buildDayBuckets(windows);
  assert.equal([...days.values()][0].pressureSum / [...days.values()][0].pressureSamples, 1000);
});

// planWeatherLookups: deduping

test('two buckets whose centroids round to the same region+hour produce ONE lookup', () => {
  // Two H3 cells close enough together to round to the same 0.25 deg / hour key.
  const cellA = latLngToCell(48.856, 2.352, 9);
  const cellB = latLngToCell(48.857, 2.353, 9); // a few hundred metres away, same 0.25 deg cell
  const windows = new Map([
    ['w1', makeWindowAcc({ h3Index: cellA, windowStart: new Date(T0) })],
    ['w2', makeWindowAcc({ h3Index: cellB, windowStart: new Date(T0) })],
  ]);
  const lookups = planWeatherLookups(windows);
  assert.equal(lookups.length, 1, `expected 1 deduped lookup, got ${lookups.length}`);
});

test('buckets far enough apart produce separate lookups', () => {
  const paris = latLngToCell(48.8566, 2.3522, 9);
  const tokyo = latLngToCell(35.6762, 139.6503, 9);
  const windows = new Map([
    ['w1', makeWindowAcc({ h3Index: paris, windowStart: new Date(T0) })],
    ['w2', makeWindowAcc({ h3Index: tokyo, windowStart: new Date(T0) })],
  ]);
  assert.equal(planWeatherLookups(windows).length, 2);
});

test('a bucket with no resolvable centroid needs no lookup', () => {
  const windows = new Map([['w1', makeWindowAcc({ h3Index: null, geohash: '' })]]);
  assert.equal(planWeatherLookups(windows).length, 0);
});

// computeWindowResults: weather wiring + fallbacks

test('pressure anomaly is local minus the fetched background, via the SAME key planWeatherLookups computed', () => {
  const cell = latLngToCell(48.8566, 2.3522, 9);
  const windowStart = new Date(T0);
  const windows = new Map([['w1', makeWindowAcc({ h3Index: cell, windowStart, pressureSum: 1010, pressureSamples: 1 })]]);
  const lookups = planWeatherLookups(windows);
  assert.equal(lookups.length, 1);
  const weatherByKey = new Map<string, WeatherObservation | null>([
    [lookups[0].key, { surfacePressureHpa: 1005, temperatureC: 18 }],
  ]);
  const [result] = computeWindowResults(windows, weatherByKey);
  assert.equal(result.avgPressure, 1010); // no neighbours -> no blend
  assert.equal(result.pressureAnomalyHpa, 5); // 1010 - 1005
  assert.equal(result.weatherTempC, 18);
});

test('a missing weather key (lookup failed) degrades to null anomaly, not a crash', () => {
  const cell = latLngToCell(48.8566, 2.3522, 9);
  const windows = new Map([['w1', makeWindowAcc({ h3Index: cell, windowStart: new Date(T0) })]]);
  const [result] = computeWindowResults(windows, new Map()); // nothing fetched successfully
  assert.equal(result.pressureAnomalyHpa, null);
  assert.equal(result.weatherTempC, null);
});

test('an empty bucket map produces no results', () => {
  assert.deepEqual(computeWindowResults(new Map(), new Map()), []);
});

// End-to-end pure pipeline on a realistic small input

test('rows -> windows -> (planned + fetched) weather -> results -> days, without any I/O', () => {
  const rows = [
    row({ t: T0, h3_res9: latLngToCell(48.8566, 2.3522, 9), summary: { count: 4, period_end: new Date(T0).toISOString(), accel_rms: 9.81, gyro_rms: 0.1, pressure: { avg: 1012, min: 1011.5, max: 1012.5 } } }),
    row({ t: T0 + WINDOW_MS, h3_res9: latLngToCell(48.8566, 2.3522, 9), summary: { count: 6, period_end: new Date(T0 + WINDOW_MS).toISOString(), accel_rms: 0, gyro_rms: 0.2, pressure: { avg: 1012.2, min: 1011.9, max: 1012.5 } } }),
  ];
  const windows = accumulateWindows(rows, WINDOW_MS, UP_TO);
  assert.equal(windows.size, 2); // different windowStart each

  const lookups = planWeatherLookups(windows);
  const weatherByKey = new Map(lookups.map(l => [l.key, { surfacePressureHpa: 1010, temperatureC: 20 } as WeatherObservation]));

  const results = computeWindowResults(windows, weatherByKey);
  assert.equal(results.length, 2);
  for (const r of results) {
    assert.ok(r.pressureAnomalyHpa !== null && r.pressureAnomalyHpa > 0);
    assert.equal(r.movementScore, 0); // both rows are "at rest" under one of the two conventions
  }

  const days = buildDayBuckets(windows);
  assert.equal(days.size, 1);
  assert.equal([...days.values()][0].samples, 10); // 4 + 6
});

// pressureSigmaHpa: observation uncertainty for downstream models
test('pressure sigma shrinks with more devices and is null without data', () => {
  assert.equal(pressureSigmaHpa(0.04, 0, 1), null);
  const one = pressureSigmaHpa(0.04, 100, 1)!;
  const four = pressureSigmaHpa(0.04, 400, 4)!;
  assert.ok(Math.abs(one - Math.sqrt(0.04 / 100 + 1)) < 1e-12);
  assert.ok(four < one / 1.9, 'four phones roughly halve the uncertainty');
});
