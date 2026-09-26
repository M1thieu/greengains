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
