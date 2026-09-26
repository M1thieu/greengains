import test from 'node:test';
import assert from 'node:assert/strict';
import { d2, rangeVariance, lagSemivariance, blendCell, CellEstimate } from './spatialBlend';

// Deterministic RNG so the simulations are reproducible.
function mulberry32(seed: number) {
  return () => {
    seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function gauss(rand: () => number) {
  const u = 1 - rand(), v = rand();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}

test('d2 matches the tabulated expected range of normals', () => {
  // Montgomery, Introduction to Statistical Quality Control, table of control-chart factors.
  const table: Array<[number, number]> = [[2, 1.128], [3, 1.693], [5, 2.326], [10, 3.078]];
  for (const [n, want] of table) assert.ok(Math.abs(d2(n) - want) < 2e-3, `d2(${n})=${d2(n)} want ${want}`);
});

test('range estimator recovers sigma on normal data', () => {
  const rand = mulberry32(1);
  const sigma = 2.5, n = 30, trials = 4000;
  let acc = 0;
  for (let t = 0; t < trials; t++) {
    let lo = Infinity, hi = -Infinity;
    for (let i = 0; i < n; i++) { const x = sigma * gauss(rand); lo = Math.min(lo, x); hi = Math.max(hi, x); }
    acc += Math.sqrt(rangeVariance(lo, hi, n)!);
  }
  const mean = acc / trials;
  assert.ok(Math.abs(mean - sigma) / sigma < 0.02, `mean sigma-hat ${mean} vs ${sigma}`);
});

test('range estimator refuses what it cannot estimate', () => {
  assert.equal(rangeVariance(1, 2, 1), null);
  assert.equal(rangeVariance(2, 1, 10), null);
  assert.equal(rangeVariance(NaN, 1, 10), null);
});

test('no evidence -> local value untouched', () => {
  assert.equal(lagSemivariance([]), null);
  const own: CellEstimate = { mean: 5, n: 10, noiseVar: 1 };
  assert.equal(blendCell(own, [], 0), 5);
});

test('exact local value is never disturbed', () => {
  const own: CellEstimate = { mean: 5, n: 10, noiseVar: 0 };
  assert.equal(blendCell(own, [{ mean: 9, n: 10, noiseVar: 1 }], 0), 5);
});

test('field identical everywhere (gamma = 0): neighbours count as much as their data warrants', () => {
  const own: CellEstimate = { mean: 10, n: 10, noiseVar: 4 };
  const nb: CellEstimate = { mean: 12, n: 30, noiseVar: 4 }; // three times the evidence
  // weights 1/0.4 and 1/(4/30): 2.5 and 7.5 -> (25 + 90) / 10 = 11.5
  assert.ok(Math.abs(blendCell(own, [nb], 0) - 11.5) < 1e-12);
});

test('rough field (large gamma) -> neighbours ignored', () => {
  const own: CellEstimate = { mean: 10, n: 10, noiseVar: 4 };
  const nb: CellEstimate = { mean: 100, n: 1000, noiseVar: 4 };
  const out = blendCell(own, [nb], 1e6);
  assert.ok(Math.abs(out - 10) < 1e-3, `${out}`);
});

// ─── Simulation with known truth on a hexagonal lattice ─────────────────────────────────────

/** Axial hex coordinates within radius R, and their six neighbour offsets. */
const DIRS: ReadonlyArray<readonly [number, number]> = [[1, 0], [1, -1], [0, -1], [-1, 0], [-1, 1], [0, 1]];
function hexes(R: number) {
  const out: Array<[number, number]> = [];
  for (let q = -R; q <= R; q++) for (let r = Math.max(-R, -q - R); r <= Math.min(R, -q + R); r++) out.push([q, r]);
  return out;
}
/** Cartesian position in units of cell spacing. */
const pos = ([q, r]: [number, number]) => [q + r / 2, (r * Math.sqrt(3)) / 2] as const;

/** Gaussian field with exponential covariance exp(-h / range), sampled by Cholesky. */
function sampleField(cells: Array<[number, number]>, range: number, rand: () => number): number[] {
  const n = cells.length;
  const C: number[][] = cells.map((a) => cells.map((b) => {
    const [ax, ay] = pos(a), [bx, by] = pos(b);
    return Math.exp(-Math.hypot(ax - bx, ay - by) / range);
  }));
  const L: number[][] = Array.from({ length: n }, () => new Array(n).fill(0));
  for (let i = 0; i < n; i++) {
    for (let j = 0; j <= i; j++) {
      let s = C[i][j] + (i === j ? 1e-9 : 0);
      for (let k = 0; k < j; k++) s -= L[i][k] * L[j][k];
      L[i][j] = i === j ? Math.sqrt(s) : s / L[j][j];
    }
  }
  const z = Array.from({ length: n }, () => gauss(rand));
  return L.map((row) => row.reduce((acc, l, k) => acc + l * z[k], 0));
}

interface Score { raw: number; old: number; blended: number }

/**
 * RMSE against the true cell values for: no blending, the previous fixed 0.35 discount, and the
 * data-driven blend. Field variance 1; each cell is observed with per-reading noise sigma.
 */
function simulate(range: number, sigma: number, seed: number, readingsFor: (i: number) => number): Score {
  const rand = mulberry32(seed);
  const cells = hexes(6);
  const index = new Map(cells.map((c, i) => [c.join(','), i]));
  const nbrs = cells.map(([q, r]) =>
    DIRS.map(([dq, dr]) => index.get(`${q + dq},${r + dr}`)).filter((i): i is number => i !== undefined));

  const trials = 60;
  const se = { raw: 0, old: 0, blended: 0 };
  let count = 0;
  for (let t = 0; t < trials; t++) {
    const truth = sampleField(cells, range, rand);
    const est: CellEstimate[] = truth.map((f, i) => {
      const n = readingsFor(i);
      let sum = 0, lo = Infinity, hi = -Infinity;
      for (let k = 0; k < n; k++) { const x = f + sigma * gauss(rand); sum += x; lo = Math.min(lo, x); hi = Math.max(hi, x); }
      return { mean: sum / n, n, noiseVar: rangeVariance(lo, hi, n) ?? 0 };
    });

    const pairs: Array<[CellEstimate, CellEstimate]> = [];
    nbrs.forEach((list, i) => list.forEach((j) => { if (i < j) pairs.push([est[i], est[j]]); }));
    const gamma = lagSemivariance(pairs);

    for (let i = 0; i < cells.length; i++) {
      if (nbrs[i].length < 6) continue; // interior cells only: edges have fewer neighbours
      const nb = nbrs[i].map((j) => est[j]);
      const oldW = nb.reduce((s, c) => s + c.n * 0.35, 0);
      const oldEst = (est[i].mean * est[i].n + nb.reduce((s, c) => s + c.mean * c.n * 0.35, 0)) / (est[i].n + oldW);
      const newEst = gamma === null ? est[i].mean : blendCell(est[i], nb, gamma);
      se.raw += (est[i].mean - truth[i]) ** 2;
      se.old += (oldEst - truth[i]) ** 2;
      se.blended += (newEst - truth[i]) ** 2;
      count++;
    }
  }
  return { raw: Math.sqrt(se.raw / count), old: Math.sqrt(se.old / count), blended: Math.sqrt(se.blended / count) };
}

test('simulation: data-driven blend beats raw when the field is smooth and cells are noisy', () => {
  const s = simulate(/* range */ 8, /* sigma */ 2, 11, () => 6);
  console.log('smooth, noisy   ', s);
  assert.ok(s.blended < s.raw * 0.9, `blended ${s.blended} vs raw ${s.raw}`);
});

test('simulation: data-driven blend does no real harm when the field is rough', () => {
  const s = simulate(/* range */ 0.3, /* sigma */ 0.3, 12, () => 40);
  console.log('rough, clean    ', s);
  assert.ok(s.blended < s.raw * 1.08, `blended ${s.blended} vs raw ${s.raw}`);
});

test('simulation across roughness x noise: harm is bounded, gains appear where the maths says', () => {
  // [field range in cells, per-reading noise, label]
  const grid: Array<[number, number, string]> = [
    [0.3, 0.3, 'rough / low noise'], [0.3, 2, 'rough / high noise'],
    [2, 0.3, 'medium / low noise'], [2, 2, 'medium / high noise'],
    [8, 0.3, 'smooth / low noise'], [8, 2, 'smooth / high noise'],
  ];
  const res = new Map<string, Score>();
  for (const [range, sigma, label] of grid) {
    const s = simulate(range, sigma, 100 + range * 10 + sigma, () => 8);
    res.set(label, s);
    console.log(label.padEnd(20), { raw: +s.raw.toFixed(3), old035: +s.old.toFixed(3), datadriven: +s.blended.toFixed(3) });
    // Harm bound: the estimator may not make things materially worse than not blending at all.
    assert.ok(s.blended <= s.raw * 1.1, `${label}: ${JSON.stringify(s)}`);
  }
  // Where the old fixed weight failed badly (fields that change within a cell), this must not.
  for (const label of ['rough / low noise', 'medium / low noise']) {
    const s = res.get(label)!;
    assert.ok(s.blended < s.old * 0.5, `${label}: ${JSON.stringify(s)}`);
  }
  // Where blending is the right tool (smooth field, noisy cells) it must actually help.
  const smoothNoisy = res.get('smooth / high noise')!;
  assert.ok(smoothNoisy.blended < smoothNoisy.raw * 0.7, JSON.stringify(smoothNoisy));
});

// Why the aggregator blends pressure but NOT light. A lux-like field spans orders of magnitude and its
// range-based noise estimate is inflated by the tail, so gamma is underestimated and the blend pools
// cells that are truly different. Measured: about 3.5x worse than not blending on a rough field.
test('light-like log-normal variable must NOT be blended in the linear domain (measured harm)', () => {
  const rand = mulberry32(77);
  const cells = hexes(6);
  const index = new Map(cells.map((c, i) => [c.join(','), i]));
  const nbrs = cells.map(([q, r]) => DIRS.map(([dq, dr]) => index.get(`${q + dq},${r + dr}`)).filter((i): i is number => i !== undefined));
  for (const range of [0.3, 8]) {
    const se = { raw: 0, blended: 0 };
    let count = 0;
    for (let t = 0; t < 60; t++) {
      const z = sampleField(cells, range, rand);
      const truth = z.map((v) => Math.exp(1.5 * v)); // lux-like: orders of magnitude
      const est: CellEstimate[] = truth.map((f) => {
        const n = 8;
        let sum = 0, lo = Infinity, hi = -Infinity;
        for (let k = 0; k < n; k++) { const x = f * Math.exp(0.5 * gauss(rand)); sum += x; lo = Math.min(lo, x); hi = Math.max(hi, x); }
        return { mean: sum / n, n, noiseVar: rangeVariance(lo, hi, n) ?? 0 };
      });
      const pairs: Array<[CellEstimate, CellEstimate]> = [];
      nbrs.forEach((list, i) => list.forEach((j) => { if (i < j) pairs.push([est[i], est[j]]); }));
      const gamma = lagSemivariance(pairs);
      for (let i = 0; i < cells.length; i++) {
        if (nbrs[i].length < 6) continue;
        const out = gamma === null ? est[i].mean : blendCell(est[i], nbrs[i].map((j) => est[j]), gamma);
        se.raw += (est[i].mean - truth[i]) ** 2; se.blended += (out - truth[i]) ** 2; count++;
      }
    }
    const raw = Math.sqrt(se.raw / count), blended = Math.sqrt(se.blended / count);
    console.log('lognormal range', range, { raw: +raw.toFixed(3), datadriven: +blended.toFixed(3) });
    if (range < 1) assert.ok(blended > raw * 1.5, `expected clear harm on a rough heavy-tailed field: ${blended} vs ${raw}`);
  }
});
