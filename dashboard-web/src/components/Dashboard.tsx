import { useState, useRef, useEffect } from 'react'
import { toast } from 'sonner'
import SensorChart from './SensorChart'
import CoverageMap from './CoverageMap'
import CommandPalette from './CommandPalette'
import FilterPanel from './FilterPanel'
import { type FilterState, DEFAULT_FILTERS, STORAGE_KEYS } from '../constants/filters'
import { SENSORS } from '../constants/sensors'
import { KPISkeleton, ChartSkeleton, CoverageSkeleton } from './LoadingSkeleton'
import { useKeyboardShortcuts } from '../hooks/useKeyboardShortcuts'
import { useDashboardData } from '../hooks/useDashboardData'
import { usePersistedUIState } from '../hooks/usePersistedUIState'
import { exportToCsv, generateCsvFilename, prepareSensorDataForExport } from '../utils/export'
import DataTable from './DataTable'
import { getSensorReadings, safeApiCall, generateMockSensorReadings } from '../api'

interface DashboardProps {
  onLogout: () => void
}

const navTabs = ['Overview', 'Aggregates', 'Coverage', 'Devices']

export default function Dashboard({ onLogout }: DashboardProps) {
  const {
    timeRange, bucket, selectedSensor,
    setTimeRange, setBucket, setSelectedSensor,
  } = usePersistedUIState()

  const [activeNav, setActiveNav] = useState('Overview')
  const [geohash, setGeohash] = useState('')
  const [dismissedAlerts, setDismissedAlerts] = useState<number[]>([])
  const [appliedGeohash, setAppliedGeohash] = useState('')
  const [isCommandPaletteOpen, setIsCommandPaletteOpen] = useState(false)
  const [isFilterPanelOpen, setIsFilterPanelOpen] = useState(false)

  const [filters, setFilters] = useState<FilterState>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.FILTERS)
      if (saved) return JSON.parse(saved)
    } catch { /* ignore */ }
    return DEFAULT_FILTERS
  })

  const [isExporting, setIsExporting] = useState(false)
  const filterButtonRef = useRef<HTMLButtonElement>(null)

  // All data fetching delegated to hook
  const {
    kpis,
    alerts,
    sensorReadings,
    coverageData,
    isLoading,
    isCoverageLoading,
    apiError,
    activeSensorCount,
    lastRefreshed,
  } = useDashboardData({ timeRange, bucket, geohash, selectedSensor })

  const systemOk = !apiError

  // Persist filter changes
  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.FILTERS, JSON.stringify(filters))
  }, [filters])

  const formatLastRefreshed = (date: Date): string => {
    const secs = Math.floor((Date.now() - date.getTime()) / 1000)
    if (secs < 60) return `${secs}s ago`
    const mins = Math.floor(secs / 60)
    return `${mins}m ago`
  }

  // Calculate active filter count
  const activeFilterCount = [
    filters.qualityMin > 0.0 || filters.qualityMax < 1.0,
    filters.lightMin > 0 || filters.lightMax < 1000,
    filters.minDevices > 1,
  ].filter(Boolean).length

  // Command palette commands
  const commands = [
    {
      id: 'sensor-light',
      label: 'Select Light Sensor',
      description: 'View light level data',
      shortcut: 'L',
      action: () => setSelectedSensor('Light'),
      category: 'Sensors' as const,
    },
    {
      id: 'sensor-movement',
      label: 'Select Movement Sensor',
      description: 'View motion detection data',
      shortcut: 'M',
      action: () => setSelectedSensor('Movement'),
      category: 'Sensors' as const,
    },
    {
      id: 'sensor-pressure',
      label: 'Select Pressure Sensor',
      description: 'View atmospheric pressure data',
      shortcut: 'P',
      action: () => setSelectedSensor('Pressure'),
      category: 'Sensors' as const,
    },
    {
      id: 'sensor-quality',
      label: 'Select Quality Sensor',
      description: 'View air quality metrics',
      shortcut: 'Q',
      action: () => setSelectedSensor('Quality'),
      category: 'Sensors' as const,
    },
    {
      id: 'range-24h',
      label: 'Last 24 Hours',
      description: 'View last day of data',
      action: () => setTimeRange('24h'),
      category: 'Filters' as const,
    },
    {
      id: 'range-7d',
      label: 'Last 7 Days',
      description: 'View week of data',
      action: () => setTimeRange('7d'),
      category: 'Filters' as const,
    },
    {
      id: 'range-30d',
      label: 'Last 30 Days',
      description: 'View month of data',
      action: () => setTimeRange('30d'),
      category: 'Filters' as const,
    },
    {
      id: 'export-csv',
      label: 'Export as CSV',
      description: 'Download data in CSV format',
      action: () => handleExportCsv(),
      category: 'Export' as const,
    },
    {
      id: 'logout',
      label: 'Sign Out',
      description: 'End your session',
      action: () => onLogout(),
      category: 'Navigation' as const,
    },
  ]

  // Keyboard shortcuts (AZERTY-safe: L/M/P/Q instead of 1/2/3/4)
  useKeyboardShortcuts({
    'cmd+k': (e) => {
      e.preventDefault()
      setIsCommandPaletteOpen((prev) => !prev)
    },
    'l': () => setSelectedSensor('Light'),
    'm': () => setSelectedSensor('Movement'),
    'p': () => setSelectedSensor('Pressure'),
    'q': () => setSelectedSensor('Quality'),
  })

  const handleApplyFilters = () => {
    setAppliedGeohash(geohash)
    // useEffect will re-trigger due to geohash state change
  }

  const handleFilterApply = (newFilters: FilterState) => {
    setFilters(newFilters)
  }

  const handleFilterReset = () => {
    setFilters(DEFAULT_FILTERS)
  }

  const handleExportCsv = async () => {
    try {
      setIsExporting(true)

      // Use current sensor readings, or fetch them if empty
      let dataToExport = sensorReadings
      if (!dataToExport || dataToExport.length === 0) {
        const params: Record<string, string | number> = {
          timeRange,
          bucket,
        }
        if (geohash) params.geohash = geohash

        dataToExport = await safeApiCall(
          () => getSensorReadings(selectedSensor, params),
          () => generateMockSensorReadings(selectedSensor, 100)
        )
      }

      // Prepare and export
      const prepared = prepareSensorDataForExport(dataToExport, selectedSensor)
      const filename = generateCsvFilename(selectedSensor, timeRange)
      exportToCsv(prepared, filename)

      toast.success(`Exported ${prepared.length} readings`, {
        description: `${selectedSensor} data · ${timeRange}`,
        duration: 3000,
      })
    } catch (error) {
      console.error('Export failed:', error)
      const message = error instanceof Error ? error.message : 'Failed to export data'
      toast.error('Export failed', {
        description: message,
        duration: 4000,
      })
    } finally {
      setIsExporting(false)
    }
  }

  const removeFilter = (filterType: keyof FilterState) => {
    setFilters((prev) => ({ ...prev, [filterType]: DEFAULT_FILTERS[filterType] }))
  }

  return (
    <div className="min-h-screen bg-[#0b111c] text-slate-200" style={{ fontVariantNumeric: 'tabular-nums' }}>
      <div className="flex flex-col h-screen overflow-hidden">

        {/* ── 1. GLOBAL STATUS BAR ── */}
        <div className={`h-7 flex items-center justify-between px-6 text-[11px] font-medium border-b transition-all ${
          systemOk
            ? 'bg-[#0b1f17] border-[#10b981]/15 text-[#10b981]'
            : 'bg-red-900/20 border-red-700/40 text-red-400'
        }`}>
          <span>{systemOk ? 'All systems operational' : 'Degraded — check alerts'}</span>
          <div className="flex items-center gap-5">
            <span className="text-slate-500">{activeSensorCount > 0 ? `${activeSensorCount} devices active` : 'No devices'}</span>
            <span className="text-slate-500">
              {lastRefreshed ? `Updated ${formatLastRefreshed(lastRefreshed)}` : `${timeRange} window`}
            </span>
            <div className="flex items-center gap-1.5">
              <div className="pulse-live h-1.5 w-1.5 rounded-full bg-[#10b981]" />
              <span>Live</span>
            </div>
          </div>
        </div>

        {/* ── 2. TOP NAV BAR ── */}
        <header className="bg-[#0d1821] border-b border-slate-800 px-6 shadow-lg" style={{ boxShadow: '0 2px 8px rgba(0, 0, 0, 0.3)' }}>
          <div className="flex items-center justify-between py-2">

            {/* Left: Brand + slash + Nav */}
            <div className="flex items-center">
              <div className="flex items-center gap-2 pr-3 border-r border-slate-800">
                <div className="h-5 w-5 flex items-center justify-center rounded bg-[#10b981] text-white font-bold text-[9px] tracking-tight">
                  GG
                </div>
                <select className="bg-transparent text-xs font-medium text-slate-300 border-none outline-none cursor-pointer">
                  <option>Boston Smart City</option>
                </select>
              </div>

              {/* Flat nav tabs */}
              <nav className="flex items-center ml-1">
                {navTabs.map((tab) => (
                  <button
                    key={tab}
                    onClick={() => setActiveNav(tab)}
                    className={`px-3 py-2 text-xs transition-colors border-b-2 ${
                      activeNav === tab
                        ? 'border-[#10b981] text-white font-medium'
                        : 'border-transparent text-slate-500 hover:text-slate-300'
                    }`}
                  >
                    {tab}
                  </button>
                ))}
              </nav>
            </div>

            {/* Right: Actions */}
            <div className="flex items-center gap-1.5">
              <button
                onClick={() => setIsCommandPaletteOpen(true)}
                className="px-2.5 py-1.5 text-[11px] text-slate-500 hover:text-slate-300 hover:bg-slate-800/30 rounded transition-all duration-200 flex items-center gap-1.5 group cursor-pointer"
                title="Open command palette (Cmd+K)"
              >
                <svg className="w-3 h-3 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
                <span className="hidden sm:inline">Search</span>
              </button>
              <button className="px-2.5 py-1.5 text-[11px] text-slate-500 hover:text-slate-300 hover:bg-slate-800/30 rounded transition-all duration-200">
                API key
              </button>
              <button className="px-2.5 py-1.5 text-[11px] text-slate-500 hover:text-slate-300 border border-slate-800 hover:border-slate-700 rounded transition-all duration-200 hover:bg-slate-800/20">
                Docs
              </button>
              <button
                onClick={onLogout}
                className="px-2.5 py-1.5 text-[11px] text-slate-400 hover:text-slate-200 border border-slate-700 hover:border-slate-600 rounded transition-all duration-200 hover:bg-slate-800/30"
              >
                Sign out
              </button>
            </div>
          </div>

          {/* Filter bar */}
          <div className="flex items-center gap-2 py-1.5 border-t border-slate-800/40">
            <span className="text-[10px] text-slate-600 uppercase tracking-wider mr-0.5">Range</span>
            <div className="flex gap-0.5">
              {['24h', '7d', '30d', '90d'].map((r) => (
                <button
                  key={r}
                  onClick={() => {
                    setTimeRange(r)
                    handleApplyFilters()
                  }}
                  className={`px-2 py-0.5 rounded text-[11px] transition-all duration-200 font-medium relative overflow-hidden ${
                    timeRange === r
                      ? 'bg-[#10b981] text-white shadow-md active:scale-95'
                      : 'text-slate-500 hover:text-slate-300 hover:bg-slate-800/50 active:scale-95'
                  }`}
                >
                  {r}
                </button>
              ))}
            </div>

            <div className="border-l border-slate-800 h-3 mx-1" />

            <select
              value={bucket}
              onChange={(e) => {
                setBucket(e.target.value)
                handleApplyFilters()
              }}
              className="px-2 py-0.5 bg-transparent border border-slate-800 hover:border-slate-700 focus:border-[#10b981] focus:ring-2 focus:ring-[#10b981]/20 rounded text-[11px] text-slate-400 outline-none transition-all duration-200"
            >
              <option>5 minutes</option>
              <option>1 hour</option>
              <option>1 day</option>
            </select>

            <input
              type="text"
              placeholder="Geohash…"
              value={geohash}
              onChange={(e) => setGeohash(e.target.value)}
              className={`px-2 py-0.5 bg-transparent border rounded text-[11px] placeholder-slate-700 outline-none w-24 transition-all duration-200 ${
                geohash !== appliedGeohash && geohash
                  ? 'border-[#fbbf24] text-[#fbbf24] focus:border-[#fbbf24] focus:ring-2 focus:ring-[#fbbf24]/20'
                  : 'border-slate-800 hover:border-slate-700 focus:border-[#10b981] text-slate-300 focus:ring-2 focus:ring-[#10b981]/20'
              }`}
            />

            <button
              onClick={handleApplyFilters}
              disabled={isLoading}
              className="px-2.5 py-0.5 bg-[#10b981]/10 hover:bg-[#10b981]/20 active:bg-[#10b981]/30 text-[#10b981] rounded text-[11px] font-medium border border-[#10b981]/15 hover:border-[#10b981]/30 transition-all duration-200 hover:shadow-sm disabled:opacity-60 disabled:cursor-not-allowed"
            >
              {isLoading ? 'Applying...' : 'Apply'}
            </button>

            <span className="ml-auto text-[10px] text-slate-700">
              {timeRange} · {bucket}
            </span>
          </div>
        </header>

        {/* ── SCROLLABLE CONTENT ── */}
        <div className="flex-1 overflow-y-auto px-6 py-4 space-y-4">

          {/* ── FILTER CHIPS ── */}
          {activeFilterCount > 0 && (
            <div className="flex flex-wrap gap-2 pb-2">
              {(filters.qualityMin > 0.0 || filters.qualityMax < 1.0) && (
                <button
                  onClick={() => removeFilter('qualityMin')}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-[#10b981]/15 border border-[#10b981]/30 rounded-full text-xs text-[#10b981] hover:bg-[#10b981]/25 transition-all duration-200 group"
                >
                  <span>Quality {filters.qualityMin.toFixed(1)}–{filters.qualityMax.toFixed(1)}</span>
                  <span className="group-hover:text-white transition-colors">✕</span>
                </button>
              )}
              {(filters.lightMin > 0 || filters.lightMax < 1000) && (
                <button
                  onClick={() => removeFilter('lightMin')}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-[#fbbf24]/15 border border-[#fbbf24]/30 rounded-full text-xs text-[#fbbf24] hover:bg-[#fbbf24]/25 transition-all duration-200 group"
                >
                  <span>Light {filters.lightMin}–{filters.lightMax} lux</span>
                  <span className="group-hover:text-white transition-colors">✕</span>
                </button>
              )}
              {filters.minDevices > 1 && (
                <button
                  onClick={() => removeFilter('minDevices')}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-[#0ea5e9]/15 border border-[#0ea5e9]/30 rounded-full text-xs text-[#0ea5e9] hover:bg-[#0ea5e9]/25 transition-all duration-200 group"
                >
                  <span>≥ {filters.minDevices} devices</span>
                  <span className="group-hover:text-white transition-colors">✕</span>
                </button>
              )}
              <button
                onClick={handleFilterReset}
                className="text-xs text-slate-500 hover:text-slate-300 underline transition-colors"
              >
                Clear all
              </button>
            </div>
          )}

          {/* ── 3. KPI ROW ── */}
          {isLoading ? (
            <KPISkeleton />
          ) : (
            <div className="grid grid-cols-4 gap-5 fade-in">
              {kpis.map((kpi, i) => (
                <div
                  key={i}
                  className="kpi-card rounded-lg overflow-hidden cursor-default hover-scale group"
                  style={{
                    background: `linear-gradient(135deg, rgba(13, 24, 33, 0.9) 0%, rgba(${
                      kpi.color === '#10b981' ? '16, 185, 129' :
                      kpi.color === '#fbbf24' ? '251, 191, 36' :
                      kpi.color === '#0ea5e9' ? '14, 165, 233' :
                      '20, 184, 166'
                    }, 0.05) 100%)`,
                    border: `1px solid rgba(${
                      kpi.color === '#10b981' ? '16, 185, 129' :
                      kpi.color === '#fbbf24' ? '251, 191, 36' :
                      kpi.color === '#0ea5e9' ? '14, 165, 233' :
                      '20, 184, 166'
                    }, 0.2)`,
                    borderLeft: `3px solid ${kpi.color}`,
                  }}
                >
                  <div className="px-5 py-4">
                    <p className="text-xs text-slate-400 uppercase tracking-widest mb-2">{kpi.label}</p>
                    <div className="flex items-end justify-between">
                      <p className="text-2xl font-bold text-white leading-none number-pop">{kpi.value}</p>
                      {kpi.trend && (
                        <span className={`text-[10px] font-semibold mb-0.5 transition-all ${kpi.up ? 'text-[#10b981]' : 'text-red-400'}`}>
                          {kpi.up ? '↑' : '↓'} {kpi.trend}
                        </span>
                      )}
                    </div>
                    <p className="text-xs text-slate-500 mt-1">{kpi.sub}</p>
                    {/* Accent fill bar */}
                    <div className="mt-3 h-px bg-slate-800 rounded-full overflow-hidden">
                      <div
                        className="h-full rounded-full transition-all duration-500"
                        style={{ width: `${kpi.pct}%`, background: `${kpi.color}50` }}
                      />
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* ── 4. ALERTS STRIP ── */}
          {alerts.filter((_, i) => !dismissedAlerts.includes(i)).length > 0 && (
            <div className="rounded-lg overflow-hidden card-elevated">
              <div className="flex items-center justify-between px-5 py-3.5 bg-gradient-to-r from-slate-800/30 to-transparent border-b border-slate-800/60">
                <div className="flex items-center gap-3">
                  <span className="text-[10px] text-slate-500 uppercase tracking-wider font-bold">Alerts</span>
                  <span className={`px-2.5 py-0.5 text-[10px] font-bold rounded-full transition-all ${
                    alerts.filter((_, i) => !dismissedAlerts.includes(i)).filter(a => a.level === 'warn').length > 0
                      ? 'bg-yellow-500/25 text-yellow-400 pulse-border'
                      : 'bg-slate-800/50 text-slate-500'
                  }`}>
                    {alerts.filter((_, i) => !dismissedAlerts.includes(i)).filter(a => a.level === 'warn').length}
                  </span>
                </div>
                <button className="text-[10px] text-slate-600 hover:text-[#10b981] hover:font-semibold transition-all duration-200 hover:scale-105">View all</button>
              </div>
              <div className="grid grid-cols-3 divide-x divide-slate-800/50">
                {alerts.map((a, i) => !dismissedAlerts.includes(i) && (
                  <div
                    key={i}
                    className={`flex items-start gap-3 px-5 py-3.5 group relative transition-all duration-300 hover:bg-gradient-to-r hover:from-slate-900/40 hover:to-transparent ${
                      a.level === 'warn' ? 'border-l-2 border-l-yellow-500/40' : 'border-l-2 border-l-blue-500/40'
                    }`}
                  >
                    <div className={`mt-0.5 h-2.5 w-2.5 rounded-full flex-shrink-0 ${
                      a.level === 'warn' ? 'bg-yellow-500 pulse-glow' : 'bg-[#0ea5e9] pulse-glow'
                    }`} />
                    <div className="min-w-0 flex-1">
                      <p className="text-[11px] text-slate-300 leading-snug font-medium">{a.msg}</p>
                      <p className="text-[10px] text-slate-600 mt-1.5">{a.time}</p>
                    </div>
                    <button
                      onClick={() => setDismissedAlerts([...dismissedAlerts, i])}
                      className="flex-shrink-0 ml-2 text-slate-600 hover:text-red-400 opacity-0 group-hover:opacity-100 transition-all duration-200 font-bold text-lg hover:scale-125 active:scale-90"
                      title="Dismiss"
                    >
                      ✕
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* ── 5. TAB CONTENT ── */}

          {/* OVERVIEW TAB */}
          {activeNav === 'Overview' && (isLoading ? (
            <div className="grid grid-cols-3 gap-6">
              <ChartSkeleton />
              <CoverageSkeleton />
            </div>
          ) : (
          <div className="grid grid-cols-3 gap-6">

            {/* Sensor chart — 2/3 width */}
            <div
              className="col-span-2 rounded-lg overflow-hidden card-premium transition-all duration-300 group"
              style={{ background: 'linear-gradient(135deg, rgba(13, 24, 33, 0.7) 0%, rgba(15, 31, 46, 0.5) 100%)', border: '1px solid rgba(16, 185, 129, 0.15)' }}
            >
              <div className="flex items-center justify-between px-6 py-4 border-b border-slate-800">
                <div>
                  <h2 className="text-sm font-semibold text-white">Sensor Data</h2>
                  <p className="text-xs text-slate-400 mt-0.5">Environmental telemetry — {timeRange}</p>
                </div>
                <div className="flex gap-2 relative">
                  <button
                    onClick={handleExportCsv}
                    disabled={isExporting}
                    className="px-3 py-1.5 bg-slate-700 hover:bg-slate-600 active:bg-slate-800 text-xs text-slate-300 rounded transition-all duration-200 hover:text-slate-100 active:scale-95 cursor-pointer disabled:opacity-60 disabled:cursor-not-allowed"
                  >
                    {isExporting ? 'Exporting...' : 'Export CSV'}
                  </button>
                  <div className="relative">
                    <button
                      ref={filterButtonRef}
                      onClick={() => setIsFilterPanelOpen(!isFilterPanelOpen)}
                      className={`px-3 py-1.5 text-xs font-medium rounded transition-all duration-200 active:scale-95 cursor-pointer flex items-center gap-1.5 ${
                        activeFilterCount > 0
                          ? 'bg-[#10b981]/20 hover:bg-[#10b981]/30 text-[#10b981] border border-[#10b981]/30'
                          : 'bg-slate-700 hover:bg-slate-600 text-slate-300 hover:text-slate-100'
                      }`}
                    >
                      Filters
                      {activeFilterCount > 0 && (
                        <span className="inline-flex items-center justify-center w-5 h-5 text-[10px] font-bold rounded-full bg-[#10b981]/30 border border-[#10b981]/50">
                          {activeFilterCount}
                        </span>
                      )}
                    </button>
                    <FilterPanel
                      filters={filters}
                      isOpen={isFilterPanelOpen}
                      onClose={() => setIsFilterPanelOpen(false)}
                      onApply={handleFilterApply}
                      onReset={handleFilterReset}
                    />
                  </div>
                </div>
              </div>

              {/* Sensor type tabs */}
              <div className="flex border-b border-slate-700 px-6 bg-gradient-to-r from-slate-900/20 to-transparent">
                {Object.values(SENSORS).map((tab) => (
                  <button
                    key={tab.name}
                    onClick={() => setSelectedSensor(tab.name)}
                    className={`px-5 py-3.5 text-sm font-semibold border-b-2 transition-all duration-300 mr-1 ${
                      selectedSensor === tab.name ? 'text-white' : 'text-slate-500 hover:text-slate-400'
                    }`}
                    style={{
                      borderBottomColor: selectedSensor === tab.name ? tab.color : 'transparent',
                      color: selectedSensor === tab.name ? tab.color : undefined,
                    }}
                  >
                    {tab.name}
                  </button>
                ))}
              </div>

              <div className="p-6">
                <SensorChart
                  selectedSensor={selectedSensor}
                  timeRange={timeRange}
                  filters={filters}
                  data={sensorReadings}
                />
              </div>
            </div>

            {/* Coverage sidebar — 1/3 width */}
            <div
              className="rounded-lg overflow-hidden card-premium transition-all duration-300"
              style={{ background: 'linear-gradient(135deg, rgba(13, 24, 33, 0.7) 0%, rgba(15, 31, 46, 0.5) 100%)', border: '1px solid rgba(16, 185, 129, 0.15)' }}
            >
              <div className="px-6 py-4 border-b border-slate-800">
                <h2 className="text-sm font-semibold text-white">Geospatial Coverage</h2>
                <p className="text-xs text-slate-400 mt-0.5">{coverageData.length} areas — {timeRange}</p>
              </div>
              <div className="p-4">
                <CoverageMap filters={filters} data={coverageData} isLoading={isCoverageLoading} />
              </div>
            </div>
          </div>
          ))}

          {/* AGGREGATES TAB */}
          {activeNav === 'Aggregates' && (
            <div
              className="rounded-lg overflow-hidden"
              style={{ background: 'rgba(13, 24, 33, 0.7)', border: '1px solid rgba(16, 185, 129, 0.15)' }}
            >
              <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between">
                <div>
                  <h2 className="text-sm font-semibold text-white">Raw Aggregates</h2>
                  <p className="text-xs text-slate-400 mt-0.5">5-minute windows — {timeRange}</p>
                </div>
                <button
                  onClick={handleExportCsv}
                  disabled={isExporting}
                  className="px-3 py-1.5 bg-slate-700 hover:bg-slate-600 text-xs text-slate-300 rounded transition-all duration-200 disabled:opacity-60"
                >
                  {isExporting ? 'Exporting...' : 'Export CSV'}
                </button>
              </div>
              <DataTable timeRange={timeRange} bucket={bucket} geohash={geohash} />
            </div>
          )}

          {/* COVERAGE TAB */}
          {activeNav === 'Coverage' && (
            <div
              className="rounded-lg overflow-hidden"
              style={{ background: 'rgba(13, 24, 33, 0.7)', border: '1px solid rgba(16, 185, 129, 0.15)' }}
            >
              <div className="px-6 py-4 border-b border-slate-800">
                <h2 className="text-sm font-semibold text-white">Geospatial Coverage</h2>
                <p className="text-xs text-slate-400 mt-0.5">{coverageData.length} geohash areas active in last {timeRange}</p>
              </div>
              <div className="p-6">
                <CoverageMap filters={filters} data={coverageData} isLoading={isCoverageLoading} />
              </div>
            </div>
          )}

          {/* DEVICES TAB */}
          {activeNav === 'Devices' && (
            <div
              className="rounded-lg overflow-hidden p-8"
              style={{ background: 'rgba(13, 24, 33, 0.7)', border: '1px solid rgba(16, 185, 129, 0.15)' }}
            >
              <div className="grid grid-cols-3 gap-6 mb-8">
                <div className="border-l-3 border-l-[#10b981] pl-6">
                  <p className="text-xs text-slate-500 uppercase tracking-widest">Active Devices</p>
                  <p className="text-3xl font-bold text-white mt-2">{activeSensorCount}</p>
                  <p className="text-xs text-slate-600 mt-1">concurrent in window</p>
                </div>
                <div className="border-l-3 border-l-[#fbbf24] pl-6">
                  <p className="text-xs text-slate-500 uppercase tracking-widest">Data Quality</p>
                  <p className="text-3xl font-bold text-white mt-2">{kpis.find(k => k.label === 'Avg Quality')?.value ?? '—'}</p>
                  <p className="text-xs text-slate-600 mt-1">valid readings</p>
                </div>
                <div className="border-l-3 border-l-[#0ea5e9] pl-6">
                  <p className="text-xs text-slate-500 uppercase tracking-widest">Time Window</p>
                  <p className="text-3xl font-bold text-white mt-2">{timeRange}</p>
                  <p className="text-xs text-slate-600 mt-1">selected period</p>
                </div>
              </div>
              <div className="p-6 bg-slate-900/30 rounded-lg border border-slate-800/40">
                <p className="text-sm text-slate-400">Per-device analytics and fleet management</p>
                <p className="text-xs text-slate-600 mt-2">Detailed device profiles, health status, and performance trends coming soon.</p>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Command Palette */}
      <CommandPalette
        isOpen={isCommandPaletteOpen}
        onClose={() => setIsCommandPaletteOpen(false)}
        commands={commands}
        onSelectSensor={setSelectedSensor}
        onChangeTimeRange={setTimeRange}
      />
    </div>
  )
}

