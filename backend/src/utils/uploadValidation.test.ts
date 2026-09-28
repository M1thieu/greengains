import test from 'node:test';
import assert from 'node:assert/strict';
import { UploadBatchSchema } from '../models/upload';
import { validateSensorRanges } from './uploadValidation';

/** ICAO/ISO 2533 standard-atmosphere station pressure (hPa) at altitude z (m). */
const isaHpa = (z: number) => 1013.25 * Math.pow(1 - 2.25577e-5 * z, 5.25588);

const batchWithPressure = (hPa: number) =>
  UploadBatchSchema.parse({
    device_id: 'd',
    timestamp: Date.now(),
    batch: [{ t: Date.now(), pressure: hPa }],
  });

// Approximate ground elevations (m). What matters is the order of magnitude, not the last metre.
const PLACES: Array<[string, number]> = [
  ['Paris', 35],
  ['Denver', 1609],
  ['Nairobi', 1795],
  ['Mexico City', 2240],
  ['ski resort in the Alps', 2300],
  ['Bogota', 2640],
  ['La Paz', 3640],
  ['Lhasa', 3650],
  ['Everest Base Camp', 5364],
  ['Dead Sea shore', -430],
];

for (const [name, altitude] of PLACES) {
  test(`a normal reading at ${name} (${altitude} m, ~${isaHpa(altitude).toFixed(0)} hPa) is not rejected`, () => {
    assert.equal(validateSensorRanges(batchWithPressure(isaHpa(altitude))), null);
  });
}

test('weather on top of altitude does not push a real reading out of range', () => {
  // A deep low (-40 hPa) in Mexico City and a strong high (+25 hPa) at the Dead Sea.
  assert.equal(validateSensorRanges(batchWithPressure(isaHpa(2240) - 40)), null);
  assert.equal(validateSensorRanges(batchWithPressure(isaHpa(-430) + 25)), null);
});

test('garbage a working barometer cannot report is still rejected', () => {
  assert.equal(validateSensorRanges(batchWithPressure(0)), 'pressure');
  assert.equal(validateSensorRanges(batchWithPressure(250)), 'pressure'); // below the sensor's 300 hPa floor
  assert.equal(validateSensorRanges(batchWithPressure(101_325)), 'pressure'); // a value in Pa sent as hPa
  assert.equal(validateSensorRanges(batchWithPressure(1101)), 'pressure'); // above the sensor's 1100 hPa ceiling
});

test('one bad reading rejects the batch, and the field is named', () => {
  const b = UploadBatchSchema.parse({
    device_id: 'd',
    timestamp: Date.now(),
    batch: [{ t: Date.now(), pressure: 1000 }, { t: Date.now() + 1000, pressure: 20 }],
  });
  assert.equal(validateSensorRanges(b), 'pressure');
});
