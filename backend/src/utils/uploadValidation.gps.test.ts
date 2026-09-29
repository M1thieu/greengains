import test from 'node:test';
import assert from 'node:assert/strict';
import type { Pool } from 'pg';
import { UploadBatchSchema } from '../models/upload';
import { checkGpsVelocity } from './uploadValidation';

/** A Pool stub whose one query always returns the given previous-fix row (or none). */
function poolWith(prevRow: { lat: number; lon: number; ts: Date } | null): Pool {
  return { query: async () => ({ rows: prevRow ? [prevRow] : [], rowCount: prevRow ? 1 : 0 }) } as unknown as Pool;
}

const PARIS = { lat: 48.8566, lon: 2.3522 };
const T0 = Date.now();

function batchAt(lat: number, lon: number, t: number) {
  return UploadBatchSchema.parse({
    device_id: 'd',
    timestamp: t,
    batch: [{ t, light: 1 }],
    location: { lat, lon, accuracy_m: 10 },
  });
}

/** Displaces PARIS eastward by the given metres (small-angle, adequate for these test distances). */
function eastOf(metres: number) {
  const mPerDegLon = 111_320 * Math.cos((PARIS.lat * Math.PI) / 180);
  return { lat: PARIS.lat, lon: PARIS.lon + metres / mPerDegLon };
}

test('no previous fix for this device -> never flagged', async () => {
  const flagged = await checkGpsVelocity(poolWith(null), 'dev', batchAt(PARIS.lat, PARIS.lon, T0));
  assert.equal(flagged, false);
});

test('a batch with no location is skipped without querying', async () => {
  let called = false;
  const pool = { query: async () => { called = true; return { rows: [], rowCount: 0 }; } } as unknown as Pool;
  const b = UploadBatchSchema.parse({ device_id: 'd', timestamp: T0, batch: [{ t: T0, light: 1 }] });
  assert.equal(await checkGpsVelocity(pool, 'dev', b), false);
  assert.equal(called, false);
});

test('same or older timestamp than the previous fix is skipped, not divide-by-zero', async () => {
  const prev = { ...PARIS, ts: new Date(T0) };
  assert.equal(await checkGpsVelocity(poolWith(prev), 'dev', batchAt(PARIS.lat, PARIS.lon, T0)), false);
  assert.equal(await checkGpsVelocity(poolWith(prev), 'dev', batchAt(PARIS.lat, PARIS.lon, T0 - 5000)), false);
});

test('CR450 commercial rail speed (400 km/h = 111.1 m/s) is accepted, not rejected as "impossible"', async () => {
  const dt = 60; // seconds
  const dest = eastOf(111.1 * dt);
  const prev = { ...PARIS, ts: new Date(T0) };
  assert.equal(await checkGpsVelocity(poolWith(prev), 'dev', batchAt(dest.lat, dest.lon, T0 + dt * 1000)), false);
});

test('a genuinely impossible jump (well past any real ground transport) is rejected', async () => {
  const dt = 60;
  const dest = eastOf(400 * dt); // 1440 km/h — no ground vehicle
  const prev = { ...PARIS, ts: new Date(T0) };
  assert.equal(await checkGpsVelocity(poolWith(prev), 'dev', batchAt(dest.lat, dest.lon, T0 + dt * 1000)), true);
});

test('a Cessna 172 at cruise (124 kt = 63.8 m/s) is still accepted, same as before the CR450 fix', async () => {
  const dt = 60;
  const dest = eastOf(63.8 * dt);
  const prev = { ...PARIS, ts: new Date(T0) };
  assert.equal(await checkGpsVelocity(poolWith(prev), 'dev', batchAt(dest.lat, dest.lon, T0 + dt * 1000)), false);
});
