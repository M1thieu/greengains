import { useState, useEffect } from 'react'
import { LineChart, Line, ResponsiveContainer } from 'recharts'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { setLanguage } from '../i18n'
import CommandPalette from './CommandPalette'
import CoverageMap from './CoverageMap'
import DataTable from './DataTable'
import FilterBar from './FilterBar'
import AlertsStrip from './AlertsStrip'
import OverviewTab from './OverviewTab'
import NetworkTab from './NetworkTab'
import { KPISkeleton } from './LoadingSkeleton'
import { type FilterState, DEFAULT_FILTERS, STORAGE_KEYS } from '../constants/filters'
import { useKeyboardShortcuts } from '../hooks/useKeyboardShortcuts'
import { useDashboardData } from '../hooks/useDashboardData'
import { usePersistedUIState } from '../hooks/usePersistedUIState'
import { exportToCsv, generateCsvFilename, prepareSensorDataForExport } from '../utils/export'
import { getSensorReadings, safeApiCall, generateMockSensorReadings } from '../api'
import { useAuth } from '../AuthContext'

interface DashboardProps {
  onLogout: () => void
}

const NAV_KEYS = ['overview', 'aggregates', 'coverage', 'network'] as const

export default function Dashboard({ onLogout }: DashboardProps) {
  const { user } = useAuth()
  const { t, i18n } = useTranslation()
  const { timeRange, bucket, selectedSensor, setTimeRange, setBucket, setSelectedSensor } = usePersistedUIState()

  const [activeNav, setActiveNav] = useState('overview')
  const [geohash, setGeohash] = useState('')
  const [appliedGeohash, setAppliedGeohash] = useState('')
  const [isCommandPaletteOpen, setIsCommandPaletteOpen] = useState(false)
  const [refreshKey, setRefreshKey] = useState(0)
  const [isExporting, setIsExporting] = useState(false)

  const [filters, setFilters] = useState<FilterState>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.FILTERS)
      if (saved) return JSON.parse(saved)
    } catch { /* ignore */ }
    return DEFAULT_FILTERS
  })

  // ── Data ──────────────────────────────────────────────────────────────────
  const {
    kpis, alerts, sensorReadings, coverageData,
    isLoading, isInitialLoad, isCoverageLoading,
    apiError, activeSensorCount, lastRefreshed, latestSensorDataAt, usingMockData,
  } = useDashboardData({ timeRange, bucket, geohash: appliedGeohash, selectedSensor, refreshKey })

  const systemOk = !apiError

  // ── Auto-refresh ──────────────────────────────────────────────────────────
  useEffect(() => {
    const INTERVALS: Record<string, number | null> = {
      '24h': 60_000, '7d': 5 * 60_000, '30d': null, '90d': null,
    }
    const ms = INTERVALS[timeRange] ?? null
    if (!ms) return
    const id = setInterval(() => { if (!document.hidden) setRefreshKey((k) => k + 1) }, ms)
    return () => clearInterval(id)
  }, [timeRange])

  // Persist filter changes
  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.FILTERS, JSON.stringify(filters))
  }, [filters])

  // ── Helpers ───────────────────────────────────────────────────────────────
  const formatLastRefreshed = (date: Date) => {
    const secs = Math.floor((Date.now() - date.getTime()) / 1000)
    if (secs < 60) return `${secs}s ago`
    return `${Math.floor(secs / 60)}m ago`
  }

  const activeFilterCount = [
    filters.qualityMin > 0.0 || filters.qualityMax < 1.0,
    filters.lightMin > 0 || filters.lightMax < 1000,
    filters.minDevices > 1,
  ].filter(Boolean).length

  const handleApplyFilters = () => setAppliedGeohash(geohash)

  const handleFilterApply = (f: FilterState) => setFilters(f)

  const handleFilterReset = () => setFilters(DEFAULT_FILTERS)

  const removeFilter = (key: 'qualityMin' | 'lightMin' | 'minDevices') => {
    if (key === 'qualityMin') setFilters((p) => ({ ...p, qualityMin: DEFAULT_FILTERS.qualityMin, qualityMax: DEFAULT_FILTERS.qualityMax }))
    else if (key === 'lightMin') setFilters((p) => ({ ...p, lightMin: DEFAULT_FILTERS.lightMin, lightMax: DEFAULT_FILTERS.lightMax }))
    else setFilters((p) => ({ ...p, minDevices: DEFAULT_FILTERS.minDevices }))
  }

  const handleExportCsv = async () => {
    try {
      setIsExporting(true)
      let data = sensorReadings
      if (!data?.length) {
        data = await safeApiCall(
          () => getSensorReadings(selectedSensor, { timeRange, bucket }),
          () => generateMockSensorReadings(selectedSensor, 100),
        )
      }
      const prepared = prepareSensorDataForExport(data, selectedSensor)
      exportToCsv(prepared, generateCsvFilename(selectedSensor, timeRange))
      toast.success(`Exported ${prepared.length} readings`, { description: `${selectedSensor} · ${timeRange}`, duration: 3000 })
    } catch (err) {
      toast.error('Export failed', { description: err instanceof Error ? err.message : 'Unknown error', duration: 4000 })
    } finally {
      setIsExporting(false)
    }
  }

  // ── Keyboard shortcuts ────────────────────────────────────────────────────
  useKeyboardShortcuts({
    'cmd+k': (e) => { e.preventDefault(); setIsCommandPaletteOpen((v) => !v) },
    'l': () => setSelectedSensor('Light'),
    'm': () => setSelectedSensor('Movement'),
    'p': () => setSelectedSensor('Pressure'),
    'q': () => setSelectedSensor('Quality'),
  })

  // ── Command palette entries ───────────────────────────────────────────────
  const commands = [
    { id: 'sensor-light',    label: t('commandPalette.sensorLight'),    description: t('commandPalette.sensorLightDesc'),    shortcut: 'L', action: () => setSelectedSensor('Light'),    category: 'Sensors'    as const },
    { id: 'sensor-movement', label: t('commandPalette.sensorMovement'), description: t('commandPalette.sensorMovementDesc'), shortcut: 'M', action: () => setSelectedSensor('Movement'), category: 'Sensors'    as const },
    { id: 'sensor-pressure', label: t('commandPalette.sensorPressure'), description: t('commandPalette.sensorPressureDesc'), shortcut: 'P', action: () => setSelectedSensor('Pressure'), category: 'Sensors'    as const },
    { id: 'sensor-quality',  label: t('commandPalette.sensorQuality'),  description: t('commandPalette.sensorQualityDesc'),  shortcut: 'Q', action: () => setSelectedSensor('Quality'),  category: 'Sensors'    as const },
    { id: 'range-24h',       label: t('commandPalette.range24h'),       description: t('commandPalette.range24hDesc'),                      action: () => setTimeRange('24h'),           category: 'Filters'    as const },
    { id: 'range-7d',        label: t('commandPalette.range7d'),        description: t('commandPalette.range7dDesc'),                       action: () => setTimeRange('7d'),            category: 'Filters'    as const },
    { id: 'range-30d',       label: t('commandPalette.range30d'),       description: t('commandPalette.range30dDesc'),                      action: () => setTimeRange('30d'),           category: 'Filters'    as const },
    { id: 'export-csv',      label: t('overview.exportCsv'),            description: t('overview.exportCsv'),                              action: () => handleExportCsv(),             category: 'Export'     as const },
    { id: 'nav-network',     label: t('nav.tabs.network'),              description: t('commandPalette.sensorQualityDesc'),                 action: () => setActiveNav('network'),       category: 'Navigation' as const },
    { id: 'logout',          label: t('login.signOut'),                 description: t('login.signOut'),                                    action: () => onLogout(),                    category: 'Navigation' as const },
  ]

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <div className="min-h-screen bg-[#0b111c] text-slate-200" style={{ fontVariantNumeric: 'tabular-nums' }}>
      <div className="flex flex-col h-screen overflow-hidden">

        {/* ── 1. STATUS BAR ── */}
        <div className={`h-7 flex items-center justify-between px-6 text-[11px] font-medium border-b transition-all ${
          !systemOk ? 'bg-red-900/20 border-red-700/40 text-red-400'
          : usingMockData ? 'bg-amber-900/20 border-amber-700/30 text-amber-400'
          : 'bg-[#071210] border-[#10b981]/10 text-[#10b981]'
        }`}>
          <div className="flex items-center gap-4">
            {usingMockData && <span className="font-semibold">{t('status.demo')}</span>}
            {!systemOk && <span className="font-semibold">{t('status.degraded')}</span>}
            {systemOk && !usingMockData && (
              <span className="text-[#10b981]/70">{t('status.operational')}</span>
            )}
          </div>
          <div className="flex items-center gap-4 text-slate-500">
            {activeSensorCount > 0 && (
              <span>{t('status.contributors', { count: activeSensorCount })}</span>
            )}
            {lastRefreshed && (
              <span>{t('status.updated', { time: formatLastRefreshed(lastRefreshed) })}</span>
            )}
            {latestSensorDataAt && (
              <span
                className={Date.now() - latestSensorDataAt.getTime() > 2 * 60 * 60 * 1000 ? 'text-amber-500' : ''}
                title="Timestamp of the most recent sensor batch"
              >
                {t('status.dataTo', { time: formatLastRefreshed(latestSensorDataAt) })}
              </span>
            )}
            <div className="flex items-center gap-1.5">
              {(timeRange === '24h' || timeRange === '7d') ? (
                <>
                  <div className="pulse-live h-1.5 w-1.5 rounded-full bg-[#10b981]" />
                  <span className="text-[#10b981]/80">{t('status.live', { interval: timeRange === '24h' ? '60s' : '5m' })}</span>
                </>
              ) : (
                <span className="text-slate-600">{t('status.dailyData')}</span>
              )}
            </div>
          </div>
        </div>

        {/* Thin refetch progress bar — only on background refreshes */}
        <div className={`h-px transition-opacity duration-300 ${isLoading && !isInitialLoad ? 'opacity-100' : 'opacity-0'}`}>
          <div className="h-full bg-[#10b981] animate-pulse" />
        </div>

        {/* ── 2. NAV BAR ── */}
        <header className="bg-[#0d1821] border-b border-slate-800 px-6 shadow-lg" style={{ boxShadow: '0 2px 8px rgba(0,0,0,0.3)' }}>
          <div className="flex items-center justify-between py-1.5">

            {/* Brand + nav tabs */}
            <div className="flex items-center">
              <div className="flex items-center gap-2 pr-3 border-r border-slate-800">
                <div className="h-5 w-5 flex items-center justify-center rounded bg-[#10b981] text-white font-bold text-[9px] tracking-tight">GG</div>
                <span className="text-xs font-medium text-slate-300">Analytics</span>
              </div>
              <nav className="flex items-center ml-1">
                {NAV_KEYS.map((key) => (
                  <button
                    key={key}
                    onClick={() => setActiveNav(key)}
                    className={`px-3 py-2 text-xs transition-colors border-b-2 ${
                      activeNav === key ? 'border-[#10b981] text-white font-medium' : 'border-transparent text-slate-500 hover:text-slate-300'
                    }`}
                  >
                    {t(`nav.tabs.${key}`)}
                  </button>
                ))}
              </nav>
            </div>

            {/* Right actions */}
            <div className="flex items-center gap-1.5">
              <button
                onClick={() => setRefreshKey((k) => k + 1)}
                disabled={isLoading}
                className="p-1.5 text-slate-500 hover:text-[#10b981] hover:bg-slate-800/30 rounded transition-all duration-200 disabled:opacity-40"
                title={t('common.refresh')}
              >
                <svg className={`w-3.5 h-3.5 ${isLoading ? 'animate-spin' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
              </button>
              <button
                onClick={() => setIsCommandPaletteOpen(true)}
                className="px-2.5 py-1.5 text-[11px] text-slate-500 hover:text-slate-300 hover:bg-slate-800/30 rounded transition-all duration-200 flex items-center gap-1.5 group cursor-pointer"
                title="Open command palette (Cmd+K)"
              >
                <svg className="w-3 h-3 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
                <span className="hidden sm:inline">{t('nav.search')}</span>
              </button>
              {user && !user.isAnonymous && (
                <div className="flex items-center gap-1.5 px-2.5 py-1 border-l border-slate-800 ml-0.5">
                  {user.photoURL ? (
                    <img src={user.photoURL} alt="" className="w-5 h-5 rounded-full" />
                  ) : (
                    <div className="w-5 h-5 rounded-full bg-slate-700 flex items-center justify-center text-[9px] text-slate-300 font-medium">
                      {(user.displayName || user.email || 'U').charAt(0).toUpperCase()}
                    </div>
                  )}
                  <span className="text-[11px] text-slate-400 max-w-[120px] truncate">{user.displayName || user.email}</span>
                </div>
              )}
              {user?.isAnonymous && <span className="text-[10px] text-slate-600 px-2 border-l border-slate-800 ml-0.5">{t('nav.demo')}</span>}
              {/* Language switcher */}
              <div className="flex items-center border-l border-slate-800 ml-0.5 pl-2 gap-0.5">
                {(['en', 'fr'] as const).map((lang) => (
                  <button
                    key={lang}
                    onClick={() => setLanguage(lang)}
                    className={`px-1.5 py-0.5 text-[10px] font-semibold rounded uppercase tracking-wide transition-all ${
                      i18n.language === lang
                        ? 'text-[#10b981] bg-[#10b981]/10'
                        : 'text-slate-600 hover:text-slate-400'
                    }`}
                  >
                    {lang}
                  </button>
                ))}
              </div>
              <button
                onClick={onLogout}
                className="px-2.5 py-1.5 text-[11px] text-slate-400 hover:text-slate-200 border border-slate-700 hover:border-slate-600 rounded transition-all duration-200 hover:bg-slate-800/30"
              >
                {t('nav.signOut')}
              </button>
            </div>
          </div>

          {/* Filter bar */}
          <FilterBar
            timeRange={timeRange} setTimeRange={setTimeRange}
            bucket={bucket} setBucket={setBucket}
            geohash={geohash} setGeohash={setGeohash}
            appliedGeohash={appliedGeohash} setAppliedGeohash={setAppliedGeohash}
            isLoading={isLoading}
            sensorReadings={sensorReadings}
            selectedSensor={selectedSensor}
            onApply={handleApplyFilters}
          />
        </header>

        {/* ── SCROLLABLE CONTENT ── */}
        <div className="flex-1 overflow-y-auto px-6 py-2 space-y-3">

          {/* ── Active filter chips ── */}
          {activeFilterCount > 0 && (
            <div className="flex flex-wrap gap-2 pb-2">
              {(filters.qualityMin > 0.0 || filters.qualityMax < 1.0) && (
                <button onClick={() => removeFilter('qualityMin')} className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-[#10b981]/15 border border-[#10b981]/30 rounded-full text-xs text-[#10b981] hover:bg-[#10b981]/25 transition-all group">
                  <span>{t('filters.quality', { min: filters.qualityMin.toFixed(1), max: filters.qualityMax.toFixed(1) })}</span>
                  <span className="group-hover:text-white transition-colors">✕</span>
                </button>
              )}
              {(filters.lightMin > 0 || filters.lightMax < 1000) && (
                <button onClick={() => removeFilter('lightMin')} className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-[#fbbf24]/15 border border-[#fbbf24]/30 rounded-full text-xs text-[#fbbf24] hover:bg-[#fbbf24]/25 transition-all group">
                  <span>{t('filters.light', { min: filters.lightMin, max: filters.lightMax })}</span>
                  <span className="group-hover:text-white transition-colors">✕</span>
                </button>
              )}
              {filters.minDevices > 1 && (
                <button onClick={() => removeFilter('minDevices')} className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-[#0ea5e9]/15 border border-[#0ea5e9]/30 rounded-full text-xs text-[#0ea5e9] hover:bg-[#0ea5e9]/25 transition-all group">
                  <span>{t('filters.minDevices', { count: filters.minDevices })}</span>
                  <span className="group-hover:text-white transition-colors">✕</span>
                </button>
              )}
              <button onClick={handleFilterReset} className="text-xs text-slate-500 hover:text-slate-300 underline transition-colors">
                {t('filters.clearAll')}
              </button>
            </div>
          )}

          {/* ── KPI row ── */}
          {isInitialLoad ? (
            <KPISkeleton />
          ) : (
            <div className="grid grid-cols-4 gap-3 fade-in">
              {kpis.map((kpi, i) => (
                <div key={i} className="kpi-card rounded-lg overflow-hidden cursor-default group" style={{ borderTop: `2px solid ${kpi.color}22`, borderLeft: `3px solid ${kpi.color}` }}>
                  <div className="px-4 pt-3 pb-1">
                    <p className="text-[10px] text-slate-500 uppercase tracking-widest font-medium mb-2">{kpi.label}</p>
                    <div className="flex items-end justify-between gap-2">
                      <p className="text-[28px] font-bold text-white leading-none number-pop tabular-nums">{kpi.value}</p>
                      {kpi.trend && (
                        <span className={`text-[10px] font-semibold mb-1 px-1.5 py-0.5 rounded-md whitespace-nowrap ${
                          kpi.up
                            ? 'text-[#10b981] bg-[#10b981]/10'
                            : 'text-red-400 bg-red-400/10'
                        }`}>
                          {kpi.up ? '↑' : '↓'} {kpi.trend}
                        </span>
                      )}
                    </div>
                    <p className="text-[11px] text-slate-500 mt-1.5">{kpi.sub}</p>
                  </div>
                  {/* Sparkline or progress bar */}
                  {kpi.sparkData && kpi.sparkData.some(v => v > 0) ? (
                    <div className="h-9 px-1 mt-1 opacity-50 group-hover:opacity-80 transition-opacity duration-300">
                      <ResponsiveContainer width="100%" height="100%">
                        <LineChart data={kpi.sparkData.map((v, idx) => ({ v, idx }))}>
                          <Line
                            type="monotone"
                            dataKey="v"
                            stroke={kpi.color}
                            strokeWidth={1.5}
                            dot={false}
                            isAnimationActive={false}
                          />
                        </LineChart>
                      </ResponsiveContainer>
                    </div>
                  ) : (
                    <div className="mx-4 mb-3 mt-2 h-px bg-slate-800/80 rounded-full overflow-hidden">
                      <div className="h-full rounded-full transition-all duration-700" style={{ width: `${kpi.pct}%`, background: `${kpi.color}60` }} />
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}

          {/* ── Alerts ── */}
          <AlertsStrip alerts={alerts} />

          {/* ── Tab content ── */}

          {activeNav === 'overview' && (
            <OverviewTab
              isInitialLoad={isInitialLoad}
              selectedSensor={selectedSensor} setSelectedSensor={setSelectedSensor}
              timeRange={timeRange}
              filters={filters} activeFilterCount={activeFilterCount}
              onFilterApply={handleFilterApply} onFilterReset={handleFilterReset}
              sensorReadings={sensorReadings} isLoading={isLoading}
              isExporting={isExporting} onExportCsv={handleExportCsv}
              coverageData={coverageData} isCoverageLoading={isCoverageLoading}
            />
          )}

          {activeNav === 'aggregates' && (
            <div className="rounded-lg overflow-hidden card-elevated">
              <div className="px-5 py-3 border-b border-slate-800 flex items-center justify-between">
                <div>
                  <h2 className="text-sm font-semibold text-white">{t('aggregates.title')}</h2>
                  <p className="text-xs text-slate-400 mt-0.5">
                    {timeRange === '30d' || timeRange === '90d'
                      ? t('aggregates.subtitleDaily', { range: timeRange })
                      : t('aggregates.subtitle5m', { range: timeRange })}
                  </p>
                </div>
                <button onClick={handleExportCsv} disabled={isExporting} className="px-3 py-1.5 bg-slate-700 hover:bg-slate-600 text-xs text-slate-300 rounded transition-all duration-200 disabled:opacity-60">
                  {isExporting ? t('overview.exporting') : t('overview.exportCsv')}
                </button>
              </div>
              <DataTable timeRange={timeRange} bucket={bucket} geohash={appliedGeohash} />
            </div>
          )}

          {activeNav === 'coverage' && (
            <div className="rounded-lg overflow-hidden card-elevated">
              <div className="px-5 py-3 border-b border-slate-800">
                <h2 className="text-sm font-semibold text-white">{t('coverage.title')}</h2>
                <p className="text-xs text-slate-400 mt-0.5">{t('coverage.subtitle', { count: coverageData.length, range: timeRange })}</p>
              </div>
              <div className="p-5">
                <CoverageMap
                  filters={filters}
                  data={coverageData}
                  isLoading={isCoverageLoading}
                  selectedGeohash={appliedGeohash}
                  onZoneSelect={(gh) => { setGeohash(gh); setAppliedGeohash(gh) }}
                />
              </div>
            </div>
          )}

          {activeNav === 'network' && (
            <NetworkTab
              coverageData={coverageData}
              activeSensorCount={activeSensorCount}
              appliedGeohash={appliedGeohash}
              timeRange={timeRange}
              isExporting={isExporting}
              onExportCsv={handleExportCsv}
              onZoneClick={(gh) => { setGeohash(gh); setAppliedGeohash(gh); setActiveNav('overview') }}
              onZoneClear={() => { setGeohash(''); setAppliedGeohash('') }}
            />
          )}

        </div>
      </div>

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
