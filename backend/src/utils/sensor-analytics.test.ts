import test from 'node:test';
import assert from 'node:assert/strict';
import { filterOutliersMad } from './sensor-analytics';

function mulberry32(seed: number) {
  return () => {
    seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const gaussian = (rand: () => number) => Math.sqrt(-2 * Math.log(1 - rand())) * Math.cos(2 * Math.PI * rand());

test('multiplier is in standard deviations: 3 rejects <1% of clean Gaussian data (0.27% asymptotically)', () => {
  const rand = mulberry32(5);
  let kept = 0, total = 0;
  for (let k = 0; k < 4000; k++) {
    const v = Array.from({ length: 60 }, () => gaussian(rand));
    kept += filterOutliersMad(v).length;
    total += v.length;
  }
  const rejected = 1 - kept / total;
  console.log(`clean Gaussian rejected: ${(100 * rejected).toFixed(2)}% (two-sided 3 sigma = 0.27%)`);
  // Two-sided tail beyond 3 sigma is 0.27%. Allow for the sampling noise of a 60-point MAD.
  assert.ok(rejected < 0.008, `rejected ${(100 * rejected).toFixed(2)}% of clean data`);
});

test('still removes a genuine outlier', () => {
  const v = [10.1, 9.9, 10.0, 10.2, 9.8, 10.05, 9.95, 10.1, 9.9, 500];
  const out = filterOutliersMad(v);
  assert.ok(!out.includes(500));
  assert.equal(out.length, v.length - 1);
});

test('flat signal and tiny windows pass through unchanged', () => {
  assert.deepEqual(filterOutliersMad([5, 5, 5, 5, 5]), [5, 5, 5, 5, 5]);
  assert.deepEqual(filterOutliersMad([1, 100, 2]), [1, 100, 2]);
});

import { qodPressureSeries, qodFrozen, QOD_PRESSURE_CONSTANT_MS } from './sensor-analytics';

const at = (min: number) => new Date(Date.UTC(2026, 9, 5, 12, 0) + min * 60_000);
const still = { motion_state: 'stationary' };
const moving = { motion_state: 'active' };

test('QoD jump: a 1.9 hPa jump within one minute between stationary readings is dropped', () => {
  const r = [
    { t: at(0), pressure: 1013.0, quality: still },
    { t: at(1), pressure: 1013.1, quality: still },
    { t: at(2), pressure: 1015.0, quality: still }, // glitch
    { t: at(3), pressure: 1013.2, quality: still },
  ];
  assert.deepEqual(qodPressureSeries(r).map(x => x.pressure), [1013.0, 1013.1, 1013.2]);
});

test('QoD jump: the bound grows with the gap (slow weather change kept) and is capped at 15 hPa', () => {
  const slow = [
    { t: at(0), pressure: 1013.0, quality: still },
    { t: at(10), pressure: 1014.5, quality: still }, // 1.5 hPa over 10 min, bound 8 hPa
  ];
  assert.equal(qodPressureSeries(slow).length, 2);
  const tooFast = [
    { t: at(0), pressure: 1013.0, quality: still },
    { t: at(60), pressure: 1033.0, quality: still }, // 20 hPa in an hour, above the 15 hPa cap
  ];
  assert.equal(qodPressureSeries(tooFast).length, 1);
});

test('QoD jump: the same change while moving is kept (hydrostatic, ~0.12 hPa per metre climbed)', () => {
  const r = [
    { t: at(0), pressure: 1013.0, quality: moving },
    { t: at(1), pressure: 1012.0, quality: moving }, // ~8 m climb
  ];
  assert.equal(qodPressureSeries(r).length, 2);
});

test('QoD constancy: identical pressure over 120 min is frozen, over 60 min is not', () => {
  const series = (span: number) => Array.from({ length: 13 }, (_, i) => ({ t: at((span / 12) * i), pressure: 1010.25 }));
  assert.equal(qodFrozen(series(120), 'pressure', QOD_PRESSURE_CONSTANT_MS), true);
  assert.equal(qodFrozen(series(60), 'pressure', QOD_PRESSURE_CONSTANT_MS), false);
});

test('QoD constancy: constant darkness is not flagged, constant non-zero light is', () => {
  const dark = Array.from({ length: 13 }, (_, i) => ({ t: at(10 * i), light: 0 }));
  const lit = Array.from({ length: 13 }, (_, i) => ({ t: at(10 * i), light: 42 }));
  assert.equal(qodFrozen(dark, 'light', QOD_PRESSURE_CONSTANT_MS), false);
  assert.equal(qodFrozen(lit, 'light', QOD_PRESSURE_CONSTANT_MS), true);
});
