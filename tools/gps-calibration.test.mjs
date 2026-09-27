import test from 'node:test';
import assert from 'node:assert/strict';
import {
  parseFixes, toLocal, estimateK, lagProfile, coverage, verdict,
  K_STRICT, K_ONE_SIGMA, COVERAGE_STRICT, COVERAGE_ONE_SIGMA,
} from './gps-calibration.mjs';

// Deterministic RNG so the simulations are reproducible.
function rng(seed) {
  let a = seed >>> 0;
  const u = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const normal = () => Math.sqrt(-2 * Math.log(1 - u())) * Math.cos(2 * Math.PI * u());
  return { u, normal };
}

const LAT = 48.8566, LON = 2.3522;
const M_LAT = 111_320, M_LON = 111_320 * Math.cos((LAT * Math.PI) / 180);

/**
 * A still phone: per-axis error = k * accuracy * (unit AR(1) with correlation time tauS), so each
 * fix's error has sd exactly k * accuracy and errors fade with lag like real GPS multipath.
 */
function simulate({ k, tauS, stepS = 10, minutes, seed }) {
  const { u, normal } = rng(seed);
  const rho = Math.exp(-stepS / tauS);
  const innov = Math.sqrt(1 - rho * rho);
  let ex = normal(), ey = normal(), acc = 8;
  const fixes = [];
  for (let i = 0; i < (minutes * 60) / stepS; i++) {
    ex = rho * ex + innov * normal();
    ey = rho * ey + innov * normal();
    acc = Math.min(20, Math.max(3, acc + (u() - 0.5))); // reported accuracy wanders a little
    const sigma = k * acc;
    fixes.push({
      t: 1_700_000_000_000 + i * stepS * 1000,
      lat: LAT + (sigma * ey) / M_LAT,
      lon: LON + (sigma * ex) / M_LON,
      acc, provider: 'fused', motion: 'STATIONARY',
    });
  }
  return fixes;
}

test('constants are the two readings of the Android definition', () => {
  assert.ok(Math.abs(K_STRICT - 0.662) < 5e-4);
  assert.equal(K_ONE_SIGMA, 1);
  assert.ok(Math.abs(COVERAGE_ONE_SIGMA - 0.3935) < 5e-4);
  // Self-consistency: under the strict reading the accuracy radius holds 68 % (Rayleigh).
  assert.ok(Math.abs(1 - Math.exp(-1 / (2 * K_STRICT ** 2)) - COVERAGE_STRICT) < 1e-9);
});

test('parses raw and prefixed logcat lines, skips fixes without accuracy', () => {
  const text = [
    '1700000000000,48.8566,2.3522,6.5,fused,STATIONARY',
    '09-27 10:00:00.000  1234  1234 D GG_FIX  : 1700000010000,48.85661,2.35221,7,fused,STATIONARY',
    '1700000020000,48.8566,2.3522,,fused,STATIONARY',
    '--------- beginning of main',
  ].join('\n');
  const fixes = parseFixes(text);
  assert.equal(fixes.length, 2);
  assert.deepEqual(fixes[1], { t: 1700000010000, lat: 48.85661, lon: 2.35221, acc: 7, provider: 'fused', motion: 'STATIONARY' });
});

// Judged over many sessions, not one seed: a single estimate is noisy by design (sd ~6 % at 60 min).
for (const k of [K_STRICT, K_ONE_SIGMA]) {
  test(`recovers k = ${k.toFixed(3)} from a still phone with correlated errors, no reference needed`, () => {
    const right = k === 1 ? 'one-sigma' : 'strict';
    const runs = Array.from({ length: 20 }, (_, i) =>
      estimateK(toLocal(simulate({ k, tauS: 60, minutes: 60, seed: 100 + i })), 300));
    const meanRatio = runs.reduce((s, e) => s + e.value / k, 0) / runs.length;
    assert.ok(Math.abs(meanRatio - 1) < 0.05, `mean k / true k = ${meanRatio}`);
    const covered = runs.filter((e) => e.lo <= k && k <= e.hi).length;
    assert.ok(covered >= 16, `95 % interval covered the truth in only ${covered}/20 sessions`);
    const verdicts = runs.map((e) => verdict(e, K_STRICT, K_ONE_SIGMA));
    assert.ok(!verdicts.some((v) => v !== right && v !== 'inconclusive'), `wrong verdict: ${verdicts}`);
    assert.ok(verdicts.filter((v) => v === right).length >= 16, `too few verdicts: ${verdicts}`);
  });
}

test('close pairs understate k while errors are correlated: the lag profile shows it', () => {
  const fixes = toLocal(simulate({ k: 1, tauS: 120, minutes: 180, seed: 3 }));
  const rows = lagProfile(fixes);
  const first = rows[0].k, last = rows.at(-1).k;
  assert.ok(first < 0.5 * last, `short-lag k ${first} should be well below long-lag k ${last}`);
});

test('a short session gives no verdict instead of a false one', () => {
  const fixes = toLocal(simulate({ k: 1, tauS: 60, minutes: 12, seed: 5 }));
  assert.equal(verdict(estimateK(fixes, 300), K_STRICT, K_ONE_SIGMA), 'inconclusive');
});

test('coverage against a known point separates 68 % from 39 %', () => {
  for (const [k, expected] of [[K_STRICT, 'strict'], [K_ONE_SIGMA, 'one-sigma']]) {
    const fixes = simulate({ k, tauS: 20, minutes: 240, seed: 19 });
    const c = coverage(fixes, LAT, LON, 300);
    assert.equal(verdict(c, COVERAGE_STRICT, COVERAGE_ONE_SIGMA), expected, `share ${c.value}`);
  }
});
