import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { getAggregatedItems } from '../api'
import { BUCKET_MAP, timeRangeToDays } from '../constants/time-ranges'
import { QUALITY } from '../constants/filters'

interface DataTableProps {
  timeRange?: string
  bucket?: string
  geohash?: string
}

interface AggregateRow {
  timestamp: string
  geohash: string
  samples_count: number
  device_count: number
  avg_light: number | null
  movement_score: number | null
  quality_valid_ratio: number | null
}

export default function DataTable({ timeRange = '24h', bucket = '5 minutes', geohash }: DataTableProps) {
  const { t } = useTranslation()
  const [data, setData] = useState<AggregateRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [sortCol, setSortCol] = useState<keyof AggregateRow>('timestamp')
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('desc')

  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true)
        setError(null)

        const now = new Date()
        const days = timeRangeToDays(timeRange)
        const from = new Date(now.getTime() - days * 24 * 60 * 60 * 1000).toISOString()
        const to = now.toISOString()

        // Mirror the smart-bucket logic from useDashboardData:
        // 30d/90d force daily aggregates — 5m buckets would produce thousands of sparse rows.
        const effectiveBucket = (timeRange === '30d' || timeRange === '90d')
          ? 'day'
          : (BUCKET_MAP[bucket] || '5m')

        const params: Record<string, string | number> = {
          from,
          to,
          bucket: effectiveBucket,
          limit: 100,
        }
        if (geohash) params.geohash = geohash

        const items = await getAggregatedItems(params)
        setData(items.slice(0, 100))
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load data')
      } finally {
        setLoading(false)
      }
    }

    fetchData()
  }, [timeRange, bucket, geohash])

  const handleSort = (col: keyof AggregateRow) => {
    if (sortCol === col) {
      setSortDir(sortDir === 'asc' ? 'desc' : 'asc')
    } else {
      setSortCol(col)
      setSortDir('desc')
    }
  }

  const sortedData = [...data].sort((a, b) => {
    const aVal = a[sortCol]
    const bVal = b[sortCol]
    if (aVal === null || aVal === undefined) return 1
    if (bVal === null || bVal === undefined) return -1
    if (typeof aVal === 'string' && typeof bVal === 'string') {
      return sortDir === 'asc' ? aVal.localeCompare(bVal) : bVal.localeCompare(aVal)
    }
    if (typeof aVal === 'number' && typeof bVal === 'number') {
      return sortDir === 'asc' ? aVal - bVal : bVal - aVal
    }
    return 0
  })

  const formatTime = (ts: string) => {
    try {
      return new Date(ts).toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
    } catch {
      return ts
    }
  }

  if (error) {
    return (
      <div className="p-6 text-center">
        <p className="text-red-400 text-sm">{error}</p>
      </div>
    )
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full">
        <thead>
          <tr className="border-b border-slate-700 bg-slate-900/50">
            {(
              [
                ['timestamp', t('dataTable.colTime')],
                ['geohash', t('dataTable.colGeohash')],
                ['samples_count', t('dataTable.colSamples')],
                ['device_count', t('dataTable.colDevices')],
                ['avg_light', t('dataTable.colAvgLight')],
                ['movement_score', t('dataTable.colMovement')],
                ['quality_valid_ratio', t('dataTable.colQuality')],
              ] as [keyof AggregateRow, string][]
            ).map(([col, label]) => (
              <th
                key={col}
                className="px-6 py-4 text-left text-xs font-semibold text-slate-300 uppercase tracking-wider cursor-pointer hover:text-white select-none group"
                onClick={() => handleSort(col)}
              >
                <span className="flex items-center gap-1">
                  {label}
                  <span className="text-slate-600 group-hover:text-slate-400 text-[10px]">
                    {sortCol === col ? (sortDir === 'asc' ? '↑' : '↓') : '↕'}
                  </span>
                </span>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {loading ? (
            <tr>
              <td colSpan={7} className="px-6 py-8 text-center">
                <div className="flex items-center justify-center gap-2">
                  <div className="animate-spin h-4 w-4 border-2 border-green-400 border-t-transparent rounded-full" />
                  <span className="text-slate-400 text-sm">{t('dataTable.loading')}</span>
                </div>
              </td>
            </tr>
          ) : sortedData.length === 0 ? (
            <tr>
              <td colSpan={7} className="px-6 py-8">
                <div className="text-center">
                  <p className="text-slate-400 text-sm font-medium">{t('dataTable.emptyTitle')}</p>
                  <p className="text-slate-600 text-xs mt-1">{t('dataTable.emptyHint')}</p>
                </div>
              </td>
            </tr>
          ) : (
            sortedData.map((row, idx) => {
              const quality = row.quality_valid_ratio
              return (
                <tr key={idx} className="border-b border-slate-700/50 hover:bg-slate-700/20 transition-colors">
                  <td className="px-6 py-3.5 text-sm text-slate-300 font-mono text-xs">{formatTime(row.timestamp)}</td>
                  <td className="px-6 py-3.5">
                    <code className="px-2 py-1 bg-slate-800 rounded text-xs text-green-400 font-mono">
                      {row.geohash}
                    </code>
                  </td>
                  <td className="px-6 py-3.5 text-sm text-slate-300">{row.samples_count.toLocaleString()}</td>
                  <td className="px-6 py-3.5 text-sm text-slate-300">{row.device_count}</td>
                  <td className="px-6 py-3.5 text-sm text-slate-300">
                    {row.avg_light !== null ? `${row.avg_light.toFixed(0)} lux` : '—'}
                  </td>
                  <td className="px-6 py-3.5 text-sm text-slate-300">
                    {row.movement_score !== null ? row.movement_score.toFixed(3) : '—'}
                  </td>
                  <td className="px-6 py-3.5">
                    {quality !== null ? (
                      <div className="flex items-center gap-2">
                        <div className="w-16 h-1.5 bg-slate-700 rounded-full overflow-hidden">
                          <div
                            className="h-full rounded-full"
                            style={{
                              width: `${quality * 100}%`,
                              background: quality >= QUALITY.GOOD ? '#10b981' : quality >= QUALITY.WARN ? '#eab308' : '#ef4444',
                            }}
                          />
                        </div>
                        <span className="text-sm font-medium text-slate-300">{(quality * 100).toFixed(0)}%</span>
                      </div>
                    ) : (
                      <span className="text-slate-600">—</span>
                    )}
                  </td>
                </tr>
              )
            })
          )}
        </tbody>
      </table>
    </div>
  )
}
