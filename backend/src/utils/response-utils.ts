/**
 * Safely convert a PostgreSQL column value to JS number.
 * Returns null for NULL / undefined values (bigint, numeric, double precision).
 */
export function numOrNull(value: unknown): number | null {
  return value !== null && value !== undefined ? Number(value) : null
}
