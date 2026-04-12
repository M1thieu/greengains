import { timeRangeToDays } from '../constants/time-ranges'

/** "Nov 23 – Feb 21, 2026" or "Today, Feb 21" for the 24h range. */
export function dateRangeLabel(timeRange: string): string {
  const now = new Date()
  const days = timeRangeToDays(timeRange)
  const fmt = (d: Date, includeYear: boolean) =>
    d.toLocaleDateString('en-GB', {
      month: 'short',
      day: 'numeric',
      ...(includeYear ? { year: 'numeric' } : {}),
    })
  if (days === 1) return `Today, ${fmt(now, false)}`
  const from = new Date(now.getTime() - days * 86_400_000)
  const crossYear = from.getFullYear() !== now.getFullYear()
  return `${fmt(from, crossYear)} – ${fmt(now, crossYear)}`
}
