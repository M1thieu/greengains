import { useState, useEffect } from 'react'
import { getAggregatedItems } from '../api'

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
  const [data, setData] = useState<AggregateRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true)
        setError(null)

        const now = new Date()
        const days = timeRange === '24h' ? 1 : timeRange === '7d' ? 7 : timeRange === '30d' ? 30 : 90
        const from = new Date(now.getTime() - days * 24 * 60 * 60 * 1000).toISOString()
        const to = now.toISOString()

        const bucketMap: Record<string, string> = {
          '5 minutes': '5m',
          '1 hour': '5m',
          '1 day': 'day',
        }

        const params: Record<string, string | number> = {
          from,
          to,
          bucket: bucketMap[bucket] || '5m',
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
            <th className="px-6 py-4 text-left text-xs font-semibold text-slate-300 uppercase tracking-wider">Time</th>
            <th className="px-6 py-4 text-left text-xs font-semibold text-slate-300 uppercase tracking-wider">Geohash</th>
            <th className="px-6 py-4 text-left text-xs font-semibold text-slate-300 uppercase tracking-wider">Samples</th>
            <th className="px-6 py-4 text-left text-xs font-semibold text-slate-300 uppercase tracking-wider">Devices</th>
            <th className="px-6 py-4 text-left text-xs font-semibold text-slate-300 uppercase tracking-wider">Avg Light</th>
            <th className="px-6 py-4 text-left text-xs font-semibold text-slate-300 uppercase tracking-wider">Movement</th>
            <th className="px-6 py-4 text-left text-xs font-semibold text-slate-300 uppercase tracking-wider">Quality</th>
          </tr>
        </thead>
        <tbody>
          {loading ? (
            <tr>
              <td colSpan={7} className="px-6 py-8 text-center">
                <div className="flex items-center justify-center gap-2">
                  <div className="animate-spin h-4 w-4 border-2 border-green-400 border-t-transparent rounded-full" />
                  <span className="text-slate-400 text-sm">Loading data...</span>
                </div>
              </td>
            </tr>
          ) : data.length === 0 ? (
            <tr>
              <td colSpan={7} className="px-6 py-8 text-center text-slate-400 text-sm">
                No data available for this time range
              </td>
            </tr>
          ) : (
            data.map((row, idx) => {
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
                              background: quality >= 0.8 ? '#10b981' : quality >= 0.6 ? '#eab308' : '#ef4444',
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
