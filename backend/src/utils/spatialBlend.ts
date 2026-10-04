/**
 * Spatial blending of neighbouring H3 cells, with every weight estimated from the data itself.
 *
 * Replaces a hand-set "neighbour counts for 0.35 of a local sample" weight. The problem is the
 * classic Optimal Interpolation one: estimate a cell's true value f0 from its own mean y0 and
 * from the means y_i of adjacent cells. A neighbour is a worse predictor of f0 than an equal
 * amount of local data, and by how much depends on how fast the field changes over one cell
 * spacing. That is measurable: for adjacent cells i, j
 *
 *     E[(y_i - y_j)^2] = 2 * gamma(h1) + v_i + v_j
 *
 * where gamma(h1) is the semivariogram at the neighbour lag (Matheron; Cressie 1993) and v is the
 * sampling variance of a cell mean. So gamma(h1) = mean[(d^2 - v_i - v_j) / 2] over the observed
 * adjacent pairs, a method-of-moments estimate that needs no assumed correlation, range or sill.
 * The same estimator is how random-effects meta-analysis measures between-study variance
 * (DerSimonian & Laird 1986). A neighbour then predicts f0 with error variance
 * v_i + 2 * gamma(h1), and the blend is the inverse-variance (BLUE) combination.
 *
 * Consequences that fall out of the maths rather than being tuned:
 *   - field varies quickly across a cell  -> gamma large -> neighbours barely count
 *   - field smooth, own cell sparse/noisy -> gamma ~ 0    -> neighbours count fully
 *   - no evidence to estimate gamma       -> return the local value untouched
 *
 * Noise v_i comes from each batch's own (min, max, n) through the range estimator
 * sigma = (max - min) / d2(n) (Tippett 1925), so no separate calibration run is needed.
 *
 * Known approximations, stated so nobody has to discover them:
 *   - Neighbour errors are treated as independent. They share f0, so they are positively
 *     correlated (0.5 for edge-adjacent hexes under an intrinsic model); the blend therefore
 *     trusts the neighbourhood somewhat more than an exact GLS solution would.
 *   - Readings inside a batch are autocorrelated, which makes v_i too small and gamma too
 *     large: both errors push toward LESS blending, the safe direction.
 *   - The range estimator assumes roughly normal noise; heavy-tailed variables overestimate it.
 */

export interface CellEstimate {
  mean: number;
  /** Number of readings behind the mean. */
  n: number;
  /** Variance of ONE reading in this cell (readings-weighted over its batches). */
  noiseVar: number;
}

const cellVariance = (c: CellEstimate) => c.noiseVar / c.n;

// Noise from (min, max, n): range estimator, d2 of statistical process control

/** Abramowitz & Stegun 7.1.26, |error| < 1.5e-7. */
function erf(x: number): number {
  const s = x < 0 ? -1 : 1;
  const a = Math.abs(x);
  const t = 1 / (1 + 0.3275911 * a);
  const poly = t * (0.254829592 + t * (-0.284496736 + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))));
  return s * (1 - poly * Math.exp(-a * a));
}
const normalCdf = (x: number) => 0.5 * (1 + erf(x / Math.SQRT2));

const d2Cache = new Map<number, number>();

/**
 * Expected range of n independent standard normals: d2(n) = integral of 1 - F^n - (1-F)^n dx.
 * Computed numerically (no lookup table), so it is exact for any n, not just the tabulated ones.
 * d2(2) = 1.128, d2(5) = 2.326, d2(10) = 3.078.
 */
export function d2(n: number): number {
  const cached = d2Cache.get(n);
  if (cached !== undefined) return cached;
  // Tails beyond +-8 contribute < n * 1e-15; trapezoid on a smooth integrand converges fast.
  const lo = -8, hi = 8, steps = 1600;
  const h = (hi - lo) / steps;
  let sum = 0;
  for (let i = 0; i <= steps; i++) {
    const F = normalCdf(lo + i * h);
    const f = 1 - Math.pow(F, n) - Math.pow(1 - F, n);
    sum += i === 0 || i === steps ? f / 2 : f;
  }
  const value = sum * h;
  d2Cache.set(n, value);
  return value;
}

/** Variance of one reading, from a batch's min, max and reading count. Null if not estimable. */
export function rangeVariance(min: number, max: number, n: number): number | null {
  if (!Number.isFinite(min) || !Number.isFinite(max) || !(n >= 2) || max < min) return null;
  const sigma = (max - min) / d2(Math.round(n));
  return sigma * sigma;
}

// Blend

/**
 * Semivariance at the neighbour lag, noise-corrected, from observed adjacent cell pairs.
 * Null when there are no pairs: without evidence about how the field varies, do not blend.
 * The floor at zero is applied to the mean, not per pair, so the estimator stays unbiased
 * until the last step.
 */
export function lagSemivariance(pairs: ReadonlyArray<readonly [CellEstimate, CellEstimate]>): number | null {
  if (pairs.length === 0) return null;
  let sum = 0;
  for (const [a, b] of pairs) {
    const d = a.mean - b.mean;
    sum += (d * d - cellVariance(a) - cellVariance(b)) / 2;
  }
  return Math.max(0, sum / pairs.length);
}

/**
 * Best linear unbiased combination of the local cell mean and its neighbours' means, where each
 * neighbour's error variance is its own sampling variance plus the representativeness variance
 * 2 * gamma(h1) of using a different cell to predict this one.
 */
export function blendCell(own: CellEstimate, neighbors: readonly CellEstimate[], gamma: number): number {
  const vOwn = cellVariance(own);
  if (neighbors.length === 0 || !(vOwn > 0)) return own.mean; // no help, or the local value is already exact

  const exact: number[] = []; // neighbours with zero error variance are exact predictors of f0
  let weightSum = 1 / vOwn;
  let weighted = own.mean / vOwn;
  for (const nb of neighbors) {
    const v = cellVariance(nb) + 2 * gamma;
    if (v <= 0) { exact.push(nb.mean); continue; }
    weightSum += 1 / v;
    weighted += nb.mean / v;
  }
  if (exact.length > 0) return exact.reduce((a, b) => a + b, 0) / exact.length;
  return weighted / weightSum;
}
