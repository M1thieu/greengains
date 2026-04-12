import { useState, useEffect } from 'react'
import { STORAGE_KEYS } from '../constants/filters'

interface UIState {
  timeRange: string
  bucket: string
  selectedSensor: string
}

const DEFAULT_UI_STATE: UIState = {
  timeRange:      '24h',
  bucket:         '5 minutes',
  selectedSensor: 'Light',
}

function loadUIState(): UIState {
  try {
    const raw = localStorage.getItem(STORAGE_KEYS.UI_STATE)
    if (raw) return { ...DEFAULT_UI_STATE, ...JSON.parse(raw) }
  } catch { /* ignore parse errors */ }
  return DEFAULT_UI_STATE
}

/**
 * Manages timeRange / bucket / selectedSensor with localStorage persistence.
 * Replaces three separate useState + useEffect blocks in Dashboard.tsx.
 */
export function usePersistedUIState() {
  const [state, setState] = useState<UIState>(loadUIState)

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.UI_STATE, JSON.stringify(state))
  }, [state])

  return {
    timeRange:      state.timeRange,
    bucket:         state.bucket,
    selectedSensor: state.selectedSensor,
    setTimeRange:      (v: string) => setState(p => ({ ...p, timeRange: v })),
    setBucket:         (v: string) => setState(p => ({ ...p, bucket: v })),
    setSelectedSensor: (v: string) => setState(p => ({ ...p, selectedSensor: v })),
  }
}
