import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts'
import React from 'react'

interface FilterState {
  qualityMin: number
  qualityMax: number
  lightMin: number
  lightMax: number
  minDevices: number
}

interface SensorChartProps {
  selectedSensor: string
  timeRange?: string
  filters?: FilterState
  data?: any[]
}

function SensorChart({ selectedSensor, timeRange, filters, data: propData }: SensorChartProps) {
  // Transform API data { timestamp, value } to chart format { time, value }
  const transformData = () => {
    if (!propData || propData.length === 0) return []

    return propData.map((point) => {
      const timestamp = point.timestamp ? new Date(point.timestamp) : null
      const time = timestamp
        ? `${timestamp.getHours().toString().padStart(2, '0')}:${timestamp.getMinutes().toString().padStart(2, '0')}`
        : '—'

      return {
        time,
        value: point.value ?? null,
        fullTimestamp: point.timestamp,
      }
    })
  }

  const rawData = transformData()

  // Apply filters to data
  const data = rawData.filter((point) => {
    if (!filters) return true

    // For readings from a single sensor, we only filter by light if it's the Light sensor
    if (selectedSensor === 'Light' && point.value !== null) {
      if (point.value < filters.lightMin || point.value > filters.lightMax) {
        return false
      }
    }

    return true
  })

  const getColorForSensor = () => {
    switch (selectedSensor) {
      case 'Light':
        return '#fbbf24'
      case 'Movement':
        return '#14b8a6'
      case 'Pressure':
        return '#0ea5e9'
      case 'Quality':
        return '#10b981'
      default:
        return '#10b981'
    }
  }

  // Calculate stats dynamically from data
  const calculateStats = () => {
    if (data.length === 0) {
      return { label: `${selectedSensor.toUpperCase()}`, value: '—', peak: '—', points: '0 points' }
    }

    const values = data.map(d => d.value).filter(v => typeof v === 'number') as number[]
    if (values.length === 0) {
      return { label: `${selectedSensor.toUpperCase()}`, value: '—', peak: '—', points: '0 points' }
    }

    const avg = (values.reduce((a, b) => a + b, 0) / values.length).toFixed(2)
    const max = Math.max(...values).toFixed(2)

    switch (selectedSensor) {
      case 'Light':
        return { label: 'AVERAGE LIGHT', value: `${avg} lux`, peak: `${max} lux`, points: `${values.length} points` }
      case 'Movement':
        return { label: 'AVG MOVEMENT', value: parseFloat(avg).toFixed(3), peak: parseFloat(max).toFixed(3), points: `${values.length} points` }
      case 'Pressure':
        return { label: 'AVG PRESSURE', value: `${avg}°`, peak: `${max}°`, points: `${values.length} points` }
      case 'Quality':
        return { label: 'AVG QUALITY', value: (parseFloat(avg) * 100).toFixed(0) + '%', peak: (parseFloat(max) * 100).toFixed(0) + '%', points: `${values.length} points` }
      default:
        return { label: 'AVERAGE', value: '—', peak: '—', points: `${values.length} points` }
    }
  }

  const stats = calculateStats()

  return (
    <div>
      {/* Stats Summary */}
      <div className="grid grid-cols-3 gap-4 mb-6">
        <div className="slide-in-left" style={{ animationDelay: '0ms' }}>
          <p className="text-xs text-slate-400 uppercase tracking-wide font-semibold">{stats.label}</p>
          <p className="text-2xl font-bold text-white mt-1 number-pop">{stats.value}</p>
        </div>
        <div className="slide-in-left" style={{ animationDelay: '100ms' }}>
          <p className="text-xs text-slate-400 uppercase tracking-wide font-semibold">PEAK {selectedSensor.toUpperCase()}</p>
          <p className="text-2xl font-bold text-white mt-1 number-pop">{stats.peak}</p>
        </div>
        <div className="slide-in-left" style={{ animationDelay: '200ms' }}>
          <p className="text-xs text-slate-400 uppercase tracking-wide font-semibold">DATA POINTS</p>
          <p className="text-2xl font-bold text-white mt-1 number-pop">{stats.points}</p>
        </div>
      </div>

      {/* Chart */}
      <div className="h-48 bg-[#0f1a1e]/30 rounded-lg p-4 fade-in border border-slate-800/50 transition-all duration-300 hover:border-slate-700/75 flex items-center justify-center" style={{ animationDelay: '300ms' }}>
        {data.length === 0 ? (
          <div className="text-center text-slate-400">
            <p className="text-sm">No data available for this time range</p>
            <p className="text-xs mt-1 text-slate-500">Try adjusting your filters or time range</p>
          </div>
        ) : (
          <ResponsiveContainer width="100%" height="100%">
            <LineChart
              data={data}
              margin={{ top: 5, right: 30, left: -20, bottom: 5 }}
            >
              <CartesianGrid strokeDasharray="3 3" stroke="#334155" opacity={0.3} />
              <XAxis
                dataKey="time"
                stroke="#94a3b8"
                style={{ fontSize: '12px' }}
              />
              <YAxis stroke="#94a3b8" style={{ fontSize: '12px' }} />
              <Tooltip
                contentStyle={{
                  backgroundColor: '#1a2635',
                  border: '1px solid #475569',
                  borderRadius: '0.5rem',
                }}
                labelStyle={{ color: '#f1f5f9' }}
              />
              <Line
                type="monotone"
                dataKey="value"
                stroke={getColorForSensor()}
                dot={{ fill: getColorForSensor(), r: 5 }}
                activeDot={{ r: 7 }}
                strokeWidth={2}
                isAnimationActive={true}
              />
            </LineChart>
          </ResponsiveContainer>
        )}
      </div>
    </div>
  )
}

export default React.memo(SensorChart)
