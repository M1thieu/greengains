export interface SensorMeta {
  name: string
  color: string
  icon: string
  /** Unit suffix shown after the value (e.g. 'lux', 'hPa', '%', '') */
  unit: string
  /** Decimal places for formatted display */
  precision: number
  /** Multiply raw value by this before display (e.g. 100 for Quality 0→1 → 0%→100%) */
  scale: number
  /**
   * Whether Recharts YAxis should allow decimal tick values.
   * Set true when raw values are in [0, 1] range — otherwise integer-only ticks
   * collapse to just 0 and 1 (e.g. Quality would only show "0%" and "100%").
   */
  yAllowDecimals: boolean
}

export const SENSORS: Record<string, SensorMeta> = {
  Light:    { name: 'Light',    color: '#fbbf24', icon: '●', unit: 'lux', precision: 0, scale: 1,   yAllowDecimals: false },
  Movement: { name: 'Movement', color: '#14b8a6', icon: '◈', unit: '',    precision: 3, scale: 1,   yAllowDecimals: true  },
  Pressure: { name: 'Pressure', color: '#0ea5e9', icon: '◆', unit: 'hPa', precision: 1, scale: 1,   yAllowDecimals: false },
  Quality:  { name: 'Quality',  color: '#10b981', icon: '✓', unit: '%',   precision: 0, scale: 100, yAllowDecimals: true  },
}

/** Format a raw sensor value for display with correct unit and precision. */
export function formatSensorValue(key: string, raw: number): string {
  const meta = SENSORS[key]
  if (!meta) return raw.toFixed(2)
  const displayed = raw * meta.scale
  const suffix = meta.unit === '%' ? '%' : (meta.unit ? ` ${meta.unit}` : '')
  return `${displayed.toFixed(meta.precision)}${suffix}`
}

/** Format a raw sensor value for a Y-axis tick (more compact). */
export function formatSensorYTick(key: string, raw: number): string {
  const meta = SENSORS[key]
  if (!meta) return String(Math.round(raw))
  const displayed = raw * meta.scale
  if (meta.scale === 1 && displayed >= 1000) return `${(displayed / 1000).toFixed(1)}k`
  const suffix = meta.unit === '%' ? '%' : ''
  return `${displayed.toFixed(meta.precision)}${suffix}`
}

export const SENSOR_NAMES = Object.keys(SENSORS)

/** Flat color lookup — drop-in replacement for per-component color maps. */
export const SENSOR_COLORS: Record<string, string> = Object.fromEntries(
  Object.entries(SENSORS).map(([k, v]) => [k, v.color])
)
