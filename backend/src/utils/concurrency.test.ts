import test from 'node:test';
import assert from 'node:assert/strict';
import { mapWithConcurrency } from './concurrency';

const delay = (ms: number) => new Promise(r => setTimeout(r, ms));

test('results come back in input order regardless of finishing order', async () => {
  const items = [30, 10, 20, 5];
  const out = await mapWithConcurrency(items, 4, async (ms) => { await delay(ms); return ms; });
  assert.deepEqual(out, items);
});

test('never runs more than `limit` calls at once', async () => {
  let inFlight = 0, maxInFlight = 0;
  await mapWithConcurrency(Array.from({ length: 20 }, (_, i) => i), 3, async () => {
    inFlight++;
    maxInFlight = Math.max(maxInFlight, inFlight);
    await delay(5);
    inFlight--;
  });
  assert.ok(maxInFlight <= 3, `maxInFlight=${maxInFlight}`);
});

test('a limit larger than the item count behaves like unlimited concurrency', async () => {
  let inFlight = 0, maxInFlight = 0;
  const out = await mapWithConcurrency([1, 2, 3], 100, async (x) => {
    inFlight++; maxInFlight = Math.max(maxInFlight, inFlight);
    await delay(5); inFlight--;
    return x * 2;
  });
  assert.deepEqual(out, [2, 4, 6]);
  assert.equal(maxInFlight, 3);
});

test('empty input resolves immediately with no calls', async () => {
  let calls = 0;
  const out = await mapWithConcurrency([], 5, async () => { calls++; return 0; });
  assert.deepEqual(out, []);
  assert.equal(calls, 0);
});

test('a rejection surfaces after in-flight calls finish, other items still ran', async () => {
  const ran: number[] = [];
  await assert.rejects(
    mapWithConcurrency([1, 2, 3, 4], 2, async (x) => {
      ran.push(x);
      if (x === 2) throw new Error('boom');
      await delay(5);
      return x;
    }),
    /boom/,
  );
  assert.deepEqual([...ran].sort((a, b) => a - b), [1, 2, 3, 4]); // every item was still attempted
});

test('limit of 1 is fully sequential', async () => {
  const order: number[] = [];
  await mapWithConcurrency([3, 1, 2], 1, async (x) => {
    order.push(x);
    await delay(1);
  });
  assert.deepEqual(order, [3, 1, 2]);
});
