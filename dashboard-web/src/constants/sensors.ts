export interface SensorMeta {
  name: string
  color: string
  icon: string
  unit: string
}

export const SENSORS: Record<string, SensorMeta> = {
  Light:    { name: 'Light',    color: '#fbbf24', icon: '●', unit: 'lux' },
  Movement: { name: 'Movement', color: '#14b8a6', icon: '◈', unit: 'RMS' },
  Pressure: { name: 'Pressure', color: '#0ea5e9', icon: '◆', unit: '°'   },
  Quality:  { name: 'Quality',  color: '#10b981', icon: '✓', unit: '%'   },
}

export const SENSOR_NAMES = Object.keys(SENSORS)

/** Flat color lookup — drop-in replacement for per-component color maps. */
export const SENSOR_COLORS: Record<string, string> = Object.fromEntries(
  Object.entries(SENSORS).map(([k, v]) => [k, v.color])
)
