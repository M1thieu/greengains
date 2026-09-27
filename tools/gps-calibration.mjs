// Measures what Location.getAccuracy() means on a given phone, to settle
// PositionFilter.SIGMA_PER_ACCURACY (android/.../service/PositionFilter.kt).
//
// The Android docs call `accuracy` the 68 % radius (strict reading: per-axis sigma = 0.662 x accuracy,
// Rayleigh) and also "one standard deviation" (per-axis sigma = 1.0 x accuracy). Only data decides.
//
// Method, no surveyed point needed: the phone lies still, so every fix is truth + error, and the
// difference of two fixes cancels the truth. If per-axis sigma = k x accuracy and the two errors
// are independent, E|p_i - p_j|^2 = 2 k^2 (a_i^2 + a_j^2), hence
//     k = sqrt( sum |p_i - p_j|^2 / (2 sum (a_i^2 + a_j^2)) ).
// GPS errors are correlated in time, so close pairs understate k. Only pairs further apart than the
// correlation time count; the lag profile printed below shows where k stops rising (the plateau).
// A bias that persists through the whole session cancels in every difference, so this k is a LOWER
// bound on the total error. `--ref lat,lon` (a surveyed point) adds the direct coverage test, which
// does see such a bias: the share of fixes within their accuracy of the truth is 68 % under the
// strict reading and 1 - e^-0.5 = 39 % under the one-sigma one.
//
// Uncertainty: delete-one-block jackknife over time blocks as long as the minimum lag, because
// pairs share fixes and nearby fixes share error; a naive per-pair interval would be far too narrow.
//
// Record (debug build, phone lying still outdoors with open sky, tracking on, >= 30 min):
//   adb logcat -c && adb logcat -s GG_FIX:D -v raw > fixes.csv
// Analyse:
//   node tools/gps-calibration.mjs fixes.csv [--min-lag 300] [--ref 48.8566,2.3522]

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

export const K_STRICT = 1 / Math.sqrt(-2 * Math.log(1 - 0.68)); // 0.662
export const K_ONE_SIGMA = 1.0;
export const COVERAGE_STRICT = 0.68;
export const COVERAGE_ONE_SIGMA = 1 - Math.exp(-0.5); // 0.393

const METRES_PER_DEG_LAT = 111_320;
const Z95 = 1.959964;

/** Parses the GG_FIX CSV lines: time_ms,lat,lon,accuracy_m,provider,motion. Other lines are skipped. */
export function parseFixes(text) {
  const re = /(\d{10,}),(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?),(\d+(?:\.\d+)?),([^,\s]*),(\w+)/;
  const fixes = [];
  for (const line of text.split(/\r?\n/)) {
    const m = re.exec(line);
    if (!m) continue; // includes fixes without an accuracy: nothing to calibrate against
    const fix = { t: Number(m[1]), lat: Number(m[2]), lon: Number(m[3]), acc: Number(m[4]), provider: m[5], motion: m[6] };
    if ([fix.t, fix.lat, fix.lon, fix.acc].every(Number.isFinite) && fix.acc > 0) fixes.push(fix);
  }
  return fixes.sort((a, b) => a.t - b.t);
}

/** Adds local metric coordinates (x east, y north, metres) around the median fix. */
export function toLocal(fixes) {
  const median = (v) => { const s = [...v].sort((a, b) => a - b); return s[Math.floor(s.length / 2)]; };
  const lat0 = median(fixes.map((f) => f.lat));
  const lon0 = median(fixes.map((f) => f.lon));
  const mPerDegLon = METRES_PER_DEG_LAT * Math.cos((lat0 * Math.PI) / 180);
  return fixes.map((f) => ({ ...f, x: (f.lon - lon0) * mPerDegLon, y: (f.lat - lat0) * METRES_PER_DEG_LAT }));
}

/**
 * Sums over pairs whose time lag is in [minLagMs, maxLagMs), split by the time blocks of the two
 * fixes so the jackknife can drop a block without a second pass over all pairs. Row b of the
 * symmetric matrices holds every pair with at least one fix in block b.
 */
function pairSums(fixes, minLagMs, maxLagMs = Infinity, blockMs = Infinity) {
  const block = blocksOf(fixes, blockMs);
  const nb = block.length ? block.at(-1) + 1 : 0;
  const rowD = new Float64Array(nb), rowA = new Float64Array(nb);
  let d2 = 0, a2 = 0, pairs = 0;
  for (let i = 0; i < fixes.length; i++) {
    for (let j = i + 1; j < fixes.length; j++) {
      const lag = fixes[j].t - fixes[i].t;
      if (lag >= maxLagMs) break; // sorted by time
      if (lag < minLagMs) continue;
      const dx = fixes[i].x - fixes[j].x, dy = fixes[i].y - fixes[j].y;
      const d = dx * dx + dy * dy, a = fixes[i].acc ** 2 + fixes[j].acc ** 2;
      d2 += d; a2 += a; pairs++;
      rowD[block[i]] += d; rowA[block[i]] += a;
      if (block[j] !== block[i]) { rowD[block[j]] += d; rowA[block[j]] += a; }
    }
  }
  return { d2, a2, pairs, block, rowD, rowA };
}

const kFrom = ({ d2, a2 }) => (a2 > 0 ? Math.sqrt(d2 / (2 * a2)) : NaN);

/** k estimated from pairs in each lag bin (seconds), to see the correlation fade out. */
export function lagProfile(fixes, edgesS = [0, 30, 60, 120, 300, 600, 1200, Infinity]) {
  const rows = [];
  for (let b = 0; b + 1 < edgesS.length; b++) {
    const s = pairSums(fixes, edgesS[b] * 1000, edgesS[b + 1] * 1000);
    rows.push({ fromS: edgesS[b], toS: edgesS[b + 1], pairs: s.pairs, k: kFrom(s) });
  }
  return rows;
}

/** Time-block labels of length blockMs, for the jackknife. */
function blocksOf(fixes, blockMs) {
  if (!fixes.length) return [];
  const t0 = fixes[0].t;
  return fixes.map((f) => (Number.isFinite(blockMs) ? Math.floor((f.t - t0) / blockMs) : 0));
}

/** 95 % interval from delete-one-block replicates; none below 5 non-empty blocks. */
function jackknife(full, reps, blocks) {
  reps = reps.filter(Number.isFinite);
  if (blocks < 5 || reps.length < 5) return { value: full, lo: NaN, hi: NaN, blocks };
  const mean = reps.reduce((s, v) => s + v, 0) / reps.length;
  const se = Math.sqrt(((reps.length - 1) / reps.length) * reps.reduce((s, v) => s + (v - mean) ** 2, 0));
  return { value: full, lo: full - Z95 * se, hi: full + Z95 * se, blocks };
}

/** k from pairs at least minLagS apart, with a 95 % block-jackknife interval (blocks of minLagS). */
export function estimateK(fixes, minLagS = 300) {
  const minLagMs = minLagS * 1000;
  const s = pairSums(fixes, minLagMs, Infinity, minLagMs);
  const ids = [...new Set(s.block)];
  const reps = ids.map((b) => kFrom({ d2: s.d2 - s.rowD[b], a2: s.a2 - s.rowA[b] }));
  return { ...jackknife(kFrom(s), reps, ids.length), pairs: s.pairs };
}

/** Share of fixes within their reported accuracy of a known true point, with a block-jackknife interval. */
export function coverage(fixes, refLat, refLon, blockS = 300) {
  const mPerDegLon = METRES_PER_DEG_LAT * Math.cos((refLat * Math.PI) / 180);
  const inside = fixes.map((f) =>
    Math.hypot((f.lon - refLon) * mPerDegLon, (f.lat - refLat) * METRES_PER_DEG_LAT) <= f.acc);
  const block = blocksOf(fixes, blockS * 1000);
  const ids = [...new Set(block)];
  const total = inside.filter(Boolean).length;
  const reps = ids.map((b) => {
    let n = 0, k = 0;
    inside.forEach((v, i) => { if (block[i] === b) { n++; if (v) k++; } });
    return fixes.length > n ? (total - k) / (fixes.length - n) : NaN;
  });
  return { ...jackknife(fixes.length ? total / fixes.length : NaN, reps, ids.length), n: fixes.length };
}

/** Which reading the interval supports: 'strict', 'one-sigma', or 'inconclusive'. */
export function verdict({ lo, hi }, strictValue, oneSigmaValue) {
  if (!Number.isFinite(lo) || !Number.isFinite(hi)) return 'inconclusive';
  const hasStrict = lo <= strictValue && strictValue <= hi;
  const hasOneSigma = lo <= oneSigmaValue && oneSigmaValue <= hi;
  if (hasStrict && !hasOneSigma) return 'strict';
  if (hasOneSigma && !hasStrict) return 'one-sigma';
  return 'inconclusive';
}

function main(argv) {
  const args = { file: null, minLag: 300, ref: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--min-lag') args.minLag = Number(argv[++i]);
    else if (argv[i] === '--ref') args.ref = argv[++i].split(',').map(Number);
    else args.file = argv[i];
  }
  if (!args.file) {
    console.error('usage: node tools/gps-calibration.mjs fixes.csv [--min-lag 300] [--ref lat,lon]');
    process.exit(2);
  }

  const fixes = toLocal(parseFixes(readFileSync(args.file, 'utf8')));
  if (fixes.length < 2) { console.error('Fewer than 2 fixes with an accuracy in the file.'); process.exit(1); }
  const minutes = (fixes.at(-1).t - fixes[0].t) / 60000;
  const count = (key) => Object.entries(fixes.reduce((m, f) => ((m[f[key]] = (m[f[key]] ?? 0) + 1), m), {}))
    .map(([k, v]) => `${k || '?'} ${v}`).join(', ');
  const accs = fixes.map((f) => f.acc).sort((a, b) => a - b);

  console.log(`${fixes.length} fixes over ${minutes.toFixed(1)} min`);
  console.log(`motion: ${count('motion')}   provider: ${count('provider')}`);
  console.log(`reported accuracy (m): median ${accs[Math.floor(accs.length / 2)]}, range ${accs[0]}-${accs.at(-1)}`);
  if (fixes.some((f) => f.motion !== 'STATIONARY')) {
    console.log('WARNING: some fixes are not flagged STATIONARY. The method assumes the phone did not move.');
  }

  console.log('\nk by time lag (rises while errors are still correlated, then levels off):');
  for (const r of lagProfile(fixes)) {
    const to = Number.isFinite(r.toS) ? `${r.toS}s` : '...';
    console.log(`  ${String(r.fromS).padStart(5)}s-${to.padEnd(6)} pairs ${String(r.pairs).padStart(7)}  k ${Number.isFinite(r.k) ? r.k.toFixed(3) : '-'}`);
  }

  const k = estimateK(fixes, args.minLag);
  console.log(`\nk from pairs >= ${args.minLag}s apart: ${k.value.toFixed(3)}  95% CI [${k.lo.toFixed(3)}, ${k.hi.toFixed(3)}]  (${k.pairs} pairs, ${k.blocks} blocks)`);
  console.log(`  strict reading ${K_STRICT.toFixed(3)}, one-sigma reading ${K_ONE_SIGMA.toFixed(3)} -> ${verdict(k, K_STRICT, K_ONE_SIGMA)}`);
  if (k.blocks < 5) console.log('  Too few blocks for an interval: record longer or lower --min-lag (only if the profile has levelled off).');
  console.log('  Lower bound: an error that persists through the whole session cancels out here. Use --ref to see it.');

  if (args.ref) {
    const c = coverage(fixes, args.ref[0], args.ref[1], args.minLag);
    console.log(`\nshare of fixes within their accuracy of the reference: ${(100 * c.value).toFixed(1)} %  95% CI [${(100 * c.lo).toFixed(1)}, ${(100 * c.hi).toFixed(1)}]`);
    console.log(`  strict reading 68 %, one-sigma reading 39 % -> ${verdict(c, COVERAGE_STRICT, COVERAGE_ONE_SIGMA)}`);
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main(process.argv.slice(2));
