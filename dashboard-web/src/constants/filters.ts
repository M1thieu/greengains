// ── Filter state ────────────────────────────────────────────────────────────

export interface FilterState {
  qualityMin: number
  qualityMax: number
  lightMin: number
  lightMax: number
  minDevices: number
}

export const DEFAULT_FILTERS: FilterState = {
  qualityMin: 0.0,
  qualityMax: 1.0,
  lightMin:   0,
  lightMax:   1000,
  minDevices: 1,
}

// ── Quality thresholds (for color-coded indicators) ───────────────────────

export const QUALITY = {
  GOOD: 0.8,
  WARN: 0.6,
} as const

export const LIGHT = {
  MIN:     0,
  MAX:     1000,
  TYPICAL: 800,
} as const

// ── localStorage keys ─────────────────────────────────────────────────────

export const STORAGE_KEYS = {
  UI_STATE: 'greengains-ui-state',
  FILTERS:  'greengains-filters',
} as const
