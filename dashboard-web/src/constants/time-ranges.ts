/** Maps UI time-range label → number of calendar days. */
export const TIME_RANGE_MAP: Record<string, number> = {
  '24h': 1,
  '7d':  7,
  '30d': 30,
  '90d': 90,
}

export const TIME_RANGES = Object.keys(TIME_RANGE_MAP)

/** Maps UI bucket label → API bucket code. */
export const BUCKET_MAP: Record<string, string> = {
  '5 minutes': '5m',
  '1 hour':    '5m',
  '1 day':     'day',
}

export const BUCKET_OPTIONS = Object.keys(BUCKET_MAP)

/** Convert a time-range label to days, defaulting to 1. */
export function timeRangeToDays(range: string): number {
  return TIME_RANGE_MAP[range] ?? 1
}
