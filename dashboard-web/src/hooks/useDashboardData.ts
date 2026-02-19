import { useState, useEffect } from 'react'
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
}

const BLANK_KPIS: KPI[] = [
  { label: 'Total Samples', value: '—', sub: 'readings',       trend: '', up: true, color: '#10b981', pct: 0 },
  { label: 'Avg Light',     value: '—', sub: 'lux',            trend: '', up: true, color: '#fbbf24', pct: 0 },
  { label: 'Active Devices',value: '—', sub: 'max concurrent', trend: '', up: true, color: '#0ea5e9', pct: 0 },
  { label: 'Avg Quality',   value: '—', sub: 'valid readings', trend: '', up: true, color: '#14b8a6', pct: 0 },
]


export function useDashboardData({ timeRange, bucket, geohash, selectedSensor }: Params) {
  const [kpis, setKpis] = useState<KPI[]>(BLANK_KPIS)
  const [alerts, setAlerts] = useState<Alert[]>([])
  const [sensorReadings, setSensorReadings] = useState<any[]>([])
  const [coverageData, setCoverageData] = useState<CoverageItem[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isCoverageLoading, setIsCoverageLoading] = useState(true)
  const [apiError, setApiError] = useState<string | null>(null)
  const [activeSensorCount, setActiveSensorCount] = useState(0)
  const [lastRefreshed, setLastRefreshed] = useState<Date | null>(null)

  useEffect(() => {
    let cancelled = false

    const fetchData = async () => {
      setIsLoading(true)
      setApiError(null)

      try {
        const now = new Date()
        const days = timeRangeToDays(timeRange)
        const from = new Date(now.getTime() - days * 24 * 60 * 60 * 1000).toISOString()
        const to = now.toISOString()

        const params: Record<string, string | number> = {
          from,
          to,
          bucket: BUCKET_MAP[bucket] || '5m',
        }
        if (geohash) params.geohash = geohash

        const [data, readings] = await Promise.all([
          safeApiCall(() => getAggregatedData(params), () => generateMockAggregatedData()),
          safeApiCall(() => getSensorReadings(selectedSensor, params), () => generateMockSensorReadings(selectedSensor)),
        ])

        if (cancelled) return

        setSensorReadings(readings)

        if (data.summary) {
          setActiveSensorCount(data.summary.activeSensors)
          setLastRefreshed(new Date())

          const lightSensor = data.sensors.find((s) => s.type === 'Light')
          const qualityPct = data.summary.averageQuality > 0
            ? `${(data.summary.averageQuality * 100).toFixed(0)}%`
            : '—'

          setKpis([
            {
              label: 'Total Samples',
              value: data.summary.totalReadings > 1000
                ? `${(data.summary.totalReadings / 1000).toFixed(1)}K`
                : String(data.summary.totalReadings),
              sub: 'readings',
              trend: '', up: true, color: '#10b981',
              pct: Math.min((data.summary.totalReadings / 5000) * 100, 100),
            },
            {
              label: 'Avg Light',
              value: lightSensor?.avgValue && lightSensor.avgValue > 0
                ? lightSensor.avgValue.toFixed(0) : '—',
              sub: 'lux',
              trend: '', up: true, color: '#fbbf24',
              pct: lightSensor?.avgValue ? Math.min((lightSensor.avgValue / 800) * 100, 100) : 0,
            },
            {
              label: 'Active Devices',
              value: data.summary.activeSensors > 0 ? String(data.summary.activeSensors) : '—',
              sub: 'max concurrent',
              trend: '', up: true, color: '#0ea5e9',
              pct: Math.min((data.summary.activeSensors / 10) * 100, 100),
            },
            {
              label: 'Avg Quality',
              value: qualityPct,
              sub: 'valid readings',
              trend: '', up: true, color: '#14b8a6',
              pct: data.summary.averageQuality * 100,
            },
          ])

          // Only surface real operational alerts — no info noise
          const newAlerts: Alert[] = []
          if (data.summary.totalReadings === 0) {
            newAlerts.push({ level: 'warn', msg: 'No sensor data in this time window', time: 'just now' })
          }
          if (data.summary.activeSensors === 0 && data.summary.totalReadings > 0) {
            newAlerts.push({ level: 'warn', msg: 'No active devices reported in this period', time: 'just now' })
          }
          if (data.summary.averageQuality > 0 && data.summary.averageQuality < 0.6) {
            newAlerts.push({
              level: 'warn',
              msg: `Data quality low — ${(data.summary.averageQuality * 100).toFixed(0)}% valid readings`,
              time: 'just now',
            })
          }
          setAlerts(newAlerts)
        }

        // Coverage fetch is non-blocking
        setIsCoverageLoading(true)
        const hours = timeRange === '24h' ? 24 : 168
        safeApiCall(() => getCoverageData({ hours }), () => []).then((coverage) => {
          if (!cancelled) {
            setCoverageData(coverage)
            setIsCoverageLoading(false)
          }
        })
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
  }, [timeRange, bucket, geohash, selectedSensor])

  return {
    kpis,
    alerts,
    sensorReadings,
    coverageData,
    isLoading,
    isCoverageLoading,
    apiError,
    activeSensorCount,
    lastRefreshed,
  }
}
