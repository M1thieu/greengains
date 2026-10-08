import test from 'node:test';
import assert from 'node:assert/strict';
import { UploadBatchSchema } from './upload';
import { summarizeBatch } from '../routes/upload';

const T = Date.now();

/** A minimal valid batch of two readings carrying the given `aux` value. */
const batchWithAux = (aux: unknown) => ({
  device_id: 'd',
  timestamp: T,
  batch: [
    { t: T, light: 100, pressure: 1013, aux },
    { t: T + 1000, light: 101, pressure: 1013.1, aux },
  ],
});

test('a valid aux map is accepted and preserved', () => {
  const r = UploadBatchSchema.safeParse(batchWithAux({ temp_ambient_c: 21.4, rh_pct: 48, lux_rear: 320, temp_baro_c: 31.2 }));
  assert.ok(r.success);
  assert.equal(r.data.batch[0].aux?.rh_pct, 48);
  assert.equal(r.data.batch[0].aux?.temp_baro_c, 31.2);
});

// An optional channel must never be able to cost us the core sensor data: each of these keeps
// the batch and its light/pressure readings, and drops only the aux map.
const hostile: Array<[string, unknown]> = [
  ['uppercase key', { Temp: 1 }],
  ['key with spaces / symbols', { 'a b': 1, 'x;drop': 2 }],
  ['string value', { rh_pct: 'wet' }],
  ['NaN value', { rh_pct: NaN }],
  ['Infinity value', { rh_pct: Infinity }],
  ['value above range', { x: 1e12 }],
  ['17 channels (cap is 16)', Object.fromEntries(Array.from({ length: 17 }, (_, i) => [`c${i}`, 1]))],
  ['array instead of map', [1, 2, 3]],
  ['null', null],
  ['key longer than 32 chars', { ['a'.repeat(40)]: 1 }],
];
for (const [name, aux] of hostile) {
  test(`hostile aux (${name}) drops only aux`, () => {
    const r = UploadBatchSchema.safeParse(batchWithAux(aux));
    assert.ok(r.success, 'batch must still be accepted');
    assert.equal(r.data.batch.length, 2);
    assert.equal(r.data.batch[0].light, 100);
    assert.equal(r.data.batch[0].pressure, 1013);
    assert.equal(r.data.batch[0].aux, undefined);
  });
}

test('summary carries a per-key aux summary, and none for old clients', () => {
  const withAux = UploadBatchSchema.parse({
    device_id: 'd',
    timestamp: T,
    batch: [
      { t: T, light: 1, aux: { temp_ambient_c: 20, lux_rear: 100 } },
      { t: T + 1000, light: 1, aux: { temp_ambient_c: 22, lux_rear: 300 } },
      { t: T + 2000, light: 1, aux: { temp_ambient_c: 21 } },
    ],
  });
  const s = summarizeBatch(withAux.batch);
  assert.deepEqual(s.aux?.temp_ambient_c, { avg: 21, min: 20, max: 22, n: 3 });
  assert.deepEqual(s.aux?.lux_rear, { avg: 200, min: 100, max: 300, n: 2 });

  const old = UploadBatchSchema.parse({ device_id: 'd', timestamp: T, batch: [{ t: T, light: 5 }] });
  assert.equal(summarizeBatch(old.batch).aux, undefined);
});

test('light read with the sensor covered (pocket, proximity, face down) is left out of the average', () => {
  const b = UploadBatchSchema.parse({
    device_id: 'd',
    timestamp: T,
    batch: [
      { t: T, light: 800, quality: { pocket: 'unlikely' } },
      { t: T + 1000, light: 2, quality: { pocket: 'likely' } },
      { t: T + 2000, light: 3, quality: { proximity_near: true } },
      { t: T + 3000, light: 1, quality: { orientation: 'face_down' } },
      { t: T + 4000, light: 820 },
    ],
  });
  assert.deepEqual(summarizeBatch(b.batch).light, { avg: 810, min: 800, max: 820 });
});
