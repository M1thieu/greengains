/**
 * Bounded-concurrency map: runs `fn` over every item, at most `limit` calls in flight at once,
 * and returns results in the same order as `items` regardless of finishing order.
 *
 * Same shape as the well-known `p-limit`/`p-map` pattern; hand-rolled here (it's a dozen lines)
 * rather than adding a dependency for it. Two things it buys over a bare `Promise.all(items.map(fn))`:
 *  - a slow or hanging call does not force every other call to have started already — useful when
 *    `fn` hits a third-party API that would otherwise see hundreds of simultaneous requests.
 *  - one item's `fn` call still runs to completion (result or rejection) independently of the
 *    others; a single failure surfaces after all currently-running calls finish, not mid-flight.
 */
export async function mapWithConcurrency<T, R>(
  items: readonly T[],
  limit: number,
  fn: (item: T, index: number) => Promise<R>,
): Promise<R[]> {
  if (items.length === 0) return [];
  const results = new Array<R>(items.length);
  let firstError: unknown;
  let hasError = false;
  let next = 0;

  async function worker(): Promise<void> {
    while (next < items.length) {
      const i = next++;
      try {
        results[i] = await fn(items[i], i);
      } catch (err) {
        if (!hasError) { hasError = true; firstError = err; }
      }
    }
  }

  await Promise.all(Array.from({ length: Math.max(1, Math.min(limit, items.length)) }, worker));
  if (hasError) throw firstError;
  return results;
}
