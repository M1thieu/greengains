import { useState, useEffect } from 'react'
import i18n from '../i18n'
import {
  getAggregatedData,
  getSensorReadings,
  getCoverageData,
  safeApiCall,
  generateMockAggregatedData,
  generateMockSensorReadings,
  CoverageItem,
} from '../api'
import { BUCKET_MAP, timeRangeToDays } from '../constants/time-ranges'

export interface KPI {
  label: string
  value: string
  sub: string
  trend: string
  up: boolean
  color: string
  pct: number
  /** 7-point daily activity count for the mini sparkline on the card. */
  sparkData?: number[]
}

export interface Alert {
  level: string
  msg: string
  time: string
}

interface Params {
  timeRange: string
  bucket: string
  geohash: string
  selectedSensor: string
  refreshKey?: number
}

const blankKpis = (): KPI[] => [
  { label: i18n.t('kpi.totalSamples'), value: '—', sub: i18n.t('kpi.readings'),       trend: '', up: true, color: '#10b981', pct: 0 },
  { label: i18n.t('kpi.zonesCovered'), value: '—', sub: i18n.t('kpi.geohashAreas'),   trend: '', up: true, color: '#0ea5e9', pct: 0 },
  { label: i18n.t('kpi.contributors'), value: '—', sub: i18n.t('kpi.activeInPeriod'), trend: '', up: true, color: '#fbbf24', pct: 0 },
  { label: i18n.t('kpi.avgQuality'),   value: '—', sub: i18n.t('kpi.validReadings'),  trend: '', up: true, color: '#14b8a6', pct: 0 },
]


export function useDashboardData({ timeRange, bucket, geohash, selectedSensor, refreshKey }: Params) {
  const [kpis, setKpis] = useState<KPI[]>(blankKpis)
  const [alerts, setAlerts] = useState<Alert[]>([])
  const [sensorReadings, setSensorReadings] = useState<any[]>([])
  const [coverageData, setCoverageData] = useState<CoverageItem[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isInitialLoad, setIsInitialLoad] = useState(true)
  const [isCoverageLoading, setIsCoverageLoading] = useState(true)
  const [apiError, setApiError] = useState<string | null>(null)
  const [activeSensorCount, setActiveSensorCount] = useState(0)
  const [lastRefreshed, setLastRefreshed] = useState<Date | null>(null)
  const [latestSensorDataAt, setLatestSensorDataAt] = useState<Date | null>(null)
  const [usingMockData, setUsingMockData] = useState(false)

  useEffect(() => {
    let cancelled = false

    const fetchData = async () => {
      setIsLoading(true)
      setApiError(null)
      // Clear chart so the skeleton shows immediately (not stale data from previous sensor/range).
      // The skeleton in SensorChart distinguishes "loading" from "genuinely no data" via isLoading.
      setSensorReadings([])

      try {
        const now = new Date()
        const days = timeRangeToDays(timeRange)
        const from = new Date(now.getTime() - days * 24 * 60 * 60 * 1000).toISOString()
        const to = now.toISOString()

        // Smart bucket: backend supports '5m' and 'day' only.
        // Wide ranges with 5-min buckets produce sparse spiky charts (thousands of empty slots).
        // Force daily aggregates for 30d/90d — matches Datadog/Grafana industry standard.
        const effectiveBucket = (timeRange === '30d' || timeRange === '90d')
          ? 'day'
          : (BUCKET_MAP[bucket] || '5m')

        const params: Record<string, string | number> = {
          from,
          to,
          bucket: effectiveBucket,
        }
        if (geohash) params.geohash = geohash

        const hours = timeRange === '24h' ? 24 : timeRange === '7d' ? 168 : timeRange === '30d' ? 720 : 2160

        setUsingMockData(false) // reset each fetch; set true below if any call falls back
        const onFallback = () => setUsingMockData(true)

        // Previous period — same window length, shifted back — for trend calculation.
        // Falls back to null (no mock) so trends are hidden when backend unavailable.
        const prevFrom = new Date(now.getTime() - 2 * days * 24 * 60 * 60 * 1000).toISOString()
        const prevParams: Record<string, string | number> = { from: prevFrom, to: from, bucket: 'day' }

        const [data, readings, coverage, prevData] = await Promise.all([
          safeApiCall(() => getAggregatedData(params), () => generateMockAggregatedData(), onFallback),
          safeApiCall(() => getSensorReadings(selectedSensor, params), () => generateMockSensorReadings(selectedSensor, timeRange), onFallback),
          safeApiCall(() => getCoverageData({ hours }), () => [] as CoverageItem[], onFallback),
          getAggregatedData(prevParams).catch(() => null),
        ])

        if (cancelled) return

        setSensorReadings(readings)
        setCoverageData(coverage)
        setIsCoverageLoading(false)

        if (data.summary) {
          setIsInitialLoad(false)
          setActiveSensorCount(data.summary.activeSensors)
          setLastRefreshed(new Date())
          setLatestSensorDataAt(data.latestDataAt ? new Date(data.latestDataAt) : null)

          const zonesCount = coverage.length
          const qualityPct = data.summary.averageQuality > 0
            ? `${(data.summary.averageQuality * 100).toFixed(0)}%`
            : '—'

          // Period-over-period trend: "+12%" or "-3%" vs previous same-length window.
          const trendStr = (curr: number, prev: number | undefined): { str: string; up: boolean } | null => {
            if (!prev || !curr) return null
            const pct = ((curr - prev) / prev) * 100
            const abs = Math.abs(pct)
            return {
              str: `${pct >= 0 ? '+' : ''}${abs < 1 ? pct.toFixed(1) : pct.toFixed(0)}%`,
              up: pct >= 0,
            }
          }
          const prev = prevData?.summary
          const readingsTrend  = trendStr(data.summary.totalReadings,  prev?.totalReadings)
          const sensorsTrend   = trendStr(data.summary.activeSensors,  prev?.activeSensors)
          const qualityTrend   = trendStr(data.summary.averageQuality, prev?.averageQuality)

          // 7-day sparkline: count readings per calendar day from sensor readings array.
          const spark7 = Array.from({ length: 7 }, (_, i) => {
            const d = new Date(now)
            d.setDate(d.getDate() - (6 - i))
            return d.toISOString().slice(0, 10)
          })
          const byDay: Record<string, number> = {}
          for (const r of readings as Array<{ timestamp: string }>) {
            const day = new Date(r.timestamp).toISOString().slice(0, 10)
            byDay[day] = (byDay[day] || 0) + 1
          }
          const sparkData = spark7.map(d => byDay[d] || 0)

          const t = i18n.t.bind(i18n)
          setKpis([
            {
              label: t('kpi.totalSamples'),
              value: data.summary.totalReadings > 1000
                ? `${(data.summary.totalReadings / 1000).toFixed(1)}K`
                : String(data.summary.totalReadings),
              sub: t('kpi.readings'),
              trend: readingsTrend?.str ?? '', up: readingsTrend?.up ?? true,
              color: '#10b981',
              pct: Math.min((data.summary.totalReadings / 5000) * 100, 100),
              sparkData,
            },
            {
              label: t('kpi.zonesCovered'),
              value: zonesCount > 0 ? String(zonesCount) : '—',
              sub: t('kpi.geohashAreas'),
              trend: '', up: true, color: '#0ea5e9',
              pct: Math.min((zonesCount / 50) * 100, 100),
            },
            {
              label: t('kpi.contributors'),
              value: data.summary.activeSensors > 0 ? String(data.summary.activeSensors) : '—',
              sub: t('kpi.activeInPeriod'),
              trend: sensorsTrend?.str ?? '', up: sensorsTrend?.up ?? true,
              color: '#fbbf24',
              pct: Math.min((data.summary.activeSensors / 10) * 100, 100),
            },
            {
              label: t('kpi.avgQuality'),
              value: qualityPct,
              sub: t('kpi.validReadings'),
              trend: qualityTrend?.str ?? '', up: qualityTrend?.up ?? true,
              color: '#14b8a6',
              pct: data.summary.averageQuality * 100,
            },
          ])

          // Surface real operational alerts with proper severity:
          // 'error' = critical, auto-resolves when data returns (non-dismissible in UI)
          // 'warn'  = degraded but functional (user-dismissible)
          const newAlerts: Alert[] = []
          if (data.summary.totalReadings === 0) {
            newAlerts.push({ level: 'error', msg: t('alerts.noData'), time: '' })
          }
          if (data.summary.activeSensors === 0 && data.summary.totalReadings > 0) {
            newAlerts.push({ level: 'warn', msg: t('alerts.noContributors'), time: '' })
          }
          if (data.summary.averageQuality > 0 && data.summary.averageQuality < 0.6) {
            newAlerts.push({
              level: 'warn',
              msg: t('alerts.qualityDegraded', { pct: (data.summary.averageQuality * 100).toFixed(0) }),
              time: '',
            })
          }
          if (data.latestDataAt && timeRange === '24h') {
            const ageMs = Date.now() - new Date(data.latestDataAt).getTime()
            if (ageMs > 2 * 60 * 60 * 1000) {
              const ageH = Math.floor(ageMs / (60 * 60 * 1000))
              newAlerts.push({
                level: 'warn',
                msg: t('alerts.staleData', { hours: ageH }),
                time: '',
              })
            }
          }
          setAlerts(newAlerts)
        }

      } catch (err) {
        if (cancelled) return
        setApiError(err instanceof Error ? err.message : 'Failed to fetch data')
        setKpis(BLANK_KPIS)
      } finally {
        if (!cancelled) setIsLoading(false)
      }
    }

    fetchData()
    return () => { cancelled = true }
  }, [timeRange, bucket, geohash, selectedSensor, refreshKey])

  return {
    kpis,
    alerts,
    sensorReadings,
    coverageData,
    isLoading,
    isInitialLoad,
    isCoverageLoading,
    apiError,
    activeSensorCount,
    lastRefreshed,
    latestSensorDataAt,
    usingMockData,
  }
}
