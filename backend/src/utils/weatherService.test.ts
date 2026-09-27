import test from 'node:test';
import assert from 'node:assert/strict';
import { _interpolationWeights, _interpolate, getWeatherAt, getWeatherStats } from './weatherService';

// ─── Pure interpolation math ────────────────────────────────────────────────────────────────

const hours = (n: number, startIso = '2026-06-01T00:00') =>
  Array.from({ length: n }, (_, i) => new Date(new Date(`${startIso}Z`).getTime() + i * 3_600_000).toISOString().slice(0, 16));

test('exact hour lands on that sample with no interpolation', () => {
  const t = hours(5);
  const w = _interpolationWeights(t, new Date(`${t[2]}Z`))!;
  assert.equal(w.i, 2);
  assert.equal(w.frac, 0);
});

test('halfway between two hours interpolates the value halfway', () => {
  const t = hours(5);
  const mid = new Date(new Date(`${t[1]}Z`).getTime() + 1_800_000); // +30 min
  const w = _interpolationWeights(t, mid)!;
  assert.equal(w.i, 1);
  assert.ok(Math.abs(w.frac - 0.5) < 1e-9);
  // Between the samples at index 1 (1010) and 2 (1020): halfway is 1015.
  assert.equal(_interpolate([1000, 1010, 1020, 1030, 1040], w), 1015);
});

test('a quarter into the hour weights 75/25 toward the earlier sample', () => {
  const t = hours(3);
  const at = new Date(new Date(`${t[0]}Z`).getTime() + 900_000); // +15 min
  const w = _interpolationWeights(t, at)!;
  assert.ok(Math.abs(_interpolate([10, 20, 30], w)! - 12.5) < 1e-9);
});

test('outside the fetched series returns null instead of extrapolating', () => {
  const t = hours(4, '2026-06-01T10:00');
  assert.equal(_interpolationWeights(t, new Date('2026-06-01T09:00:00Z')), null); // before first
  assert.equal(_interpolationWeights(t, new Date('2026-06-01T14:00:00Z')), null); // after last
});

test('exactly the last sample interpolates to itself, not out of range', () => {
  const t = hours(3);
  const w = _interpolationWeights(t, new Date(`${t[2]}Z`))!;
  assert.equal(_interpolate([1, 2, 3], w), 3);
});

test('a missing bracketing sample propagates as null, not a wrong number', () => {
  const t = hours(3);
  const at = new Date(new Date(`${t[0]}Z`).getTime() + 1_800_000);
  const w = _interpolationWeights(t, at)!;
  assert.equal(_interpolate([10, undefined, 30], w), null);
});

// ─── getWeatherAt: URL construction and end-to-end behaviour, fetch mocked (no network) ───────

function mockFetch(hourly: { time: string[]; surface_pressure?: number[]; temperature_2m?: number[] }) {
  const calls: string[] = [];
  (globalThis as any).fetch = async (url: string) => {
    calls.push(url);
    return { ok: true, json: async () => ({ hourly }) };
  };
  return calls;
}

// hours() truncates to minute precision (drops seconds/ms), so [at] must be pre-truncated the
// same way — otherwise it can land a fraction of a minute after the mocked t[0] and interpolate
// to a value a hair off 1000, which a strict equality check would then flake on.
const toMinute = (ms: number) => Math.floor(ms / 60_000) * 60_000;

test('a recent [at] requests a small past_days window, not one scaled to dozens of days', async () => {
  const at = new Date(toMinute(Date.now()));
  const t = hours(4, new Date(at.getTime() - 3_600_000).toISOString().slice(0, 16));
  const calls = mockFetch({ time: t, surface_pressure: [1010, 1011, 1012, 1013], temperature_2m: [10, 11, 12, 13] });
  const v = await getWeatherAt(48.85, 2.35, at);
  assert.ok(v && v.surfacePressureHpa !== null);
  const pastDays = Number(/past_days=(\d+)/.exec(calls[0])![1]);
  assert.ok(pastDays <= 2, `past_days=${pastDays} for an [at] that is now`);
});

test('an [at] from 40 days ago scales past_days to cover it, not the fixed value 1', async () => {
  const at = new Date(toMinute(Date.now() - 40 * 86_400_000));
  const t = hours(4, at.toISOString().slice(0, 16));
  const calls = mockFetch({ time: t, surface_pressure: [1000, 1001, 1002, 1003] });
  const v = await getWeatherAt(1, 1, at);
  assert.ok(v && v.surfacePressureHpa === 1000, `got ${v?.surfacePressureHpa}`);
  const pastDays = Number(/past_days=(\d+)/.exec(calls[0])![1]);
  assert.ok(pastDays >= 40, `past_days=${pastDays} does not cover an [at] 40 days ago`);
});

test('past_days never exceeds the documented API maximum of 92', async () => {
  const at = new Date(Date.now() - 900 * 86_400_000); // far beyond retention; the API cannot serve it anyway
  const t = hours(4, new Date(Date.now() - 2 * 86_400_000).toISOString().slice(0, 16)); // server returns what it actually has
  const calls = mockFetch({ time: t, surface_pressure: [1000, 1001, 1002, 1003] });
  const before = getWeatherStats().failed;
  await getWeatherAt(1, 1, at);
  assert.ok(Number(/past_days=(\d+)/.exec(calls[0])![1]) <= 92);
  assert.equal(getWeatherStats().failed, before + 1); // out of range -> fails rather than returning distant data
});

test('a series that does not actually cover [at] fails instead of returning the nearest available point', async () => {
  // Regression: this used to silently succeed with the closest sample, however far away.
  const at = new Date('2026-01-15T12:00:00Z');
  mockFetch({ time: hours(4, '2026-03-01T00:00'), surface_pressure: [1000, 1001, 1002, 1003] });
  const before = getWeatherStats().failed;
  const v = await getWeatherAt(2, 2, at);
  assert.equal(v, null);
  assert.equal(getWeatherStats().failed, before + 1);
});
