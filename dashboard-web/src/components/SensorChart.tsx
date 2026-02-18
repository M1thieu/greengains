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
  // Fallback mock data if no data provided
  const mockData = [
    { time: '00:00', Light: 2, Movement: 0.15, Pressure: 1013.2, Quality: 0.91 },
    { time: '02:00', Light: 1, Movement: 0.08, Pressure: 1013.5, Quality: 0.93 },
    { time: '04:00', Light: 3, Movement: 0.12, Pressure: 1013.8, Quality: 0.94 },
    { time: '06:00', Light: 18, Movement: 0.35, Pressure: 1014.1, Quality: 0.92 },
    { time: '08:00', Light: 52, Movement: 0.95, Pressure: 1014.4, Quality: 0.89 },
    { time: '10:00', Light: 78, Movement: 1.42, Pressure: 1014.6, Quality: 0.87 },
    { time: '12:00', Light: 95, Movement: 1.68, Pressure: 1014.5, Quality: 0.85 },
    { time: '14:00', Light: 88, Movement: 1.55, Pressure: 1014.2, Quality: 0.86 },
    { time: '16:00', Light: 65, Movement: 1.32, Pressure: 1014.0, Quality: 0.88 },
    { time: '18:00', Light: 35, Movement: 0.78, Pressure: 1013.8, Quality: 0.90 },
    { time: '20:00', Light: 8, Movement: 0.42, Pressure: 1013.6, Quality: 0.92 },
    { time: '22:00', Light: 4, Movement: 0.28, Pressure: 1013.4, Quality: 0.93 },
  ]

  // Use provided data or fall back to mock
  const rawData = (propData && propData.length > 0) ? propData : mockData

  // Apply filters to data
  const data = rawData.filter((point) => {
    if (!filters) return true

    // Filter by quality range
    const quality = point.Quality || point.quality
    if (quality !== undefined && (quality < filters.qualityMin || quality > filters.qualityMax)) {
      return false
    }

    // Filter by light range
    const light = point.Light || point.light
    if (light !== undefined && (light < filters.lightMin || light > filters.lightMax)) {
      return false
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
    const values = data.map(d => d[selectedSensor as keyof typeof data[0]]).filter(v => typeof v === 'number') as number[]
    const avg = (values.reduce((a, b) => a + b, 0) / values.length).toFixed(2)
    const max = Math.max(...values).toFixed(2)

    switch (selectedSensor) {
      case 'Light':
        return { label: 'AVERAGE LIGHT', value: `${avg} lux`, peak: `${max} lux`, points: `${data.length} points` }
      case 'Movement':
        return { label: 'AVG MOVEMENT', value: avg, peak: max, points: `${data.length} points` }
      case 'Pressure':
        return { label: 'AVG PRESSURE', value: `${avg} hPa`, peak: `${max} hPa`, points: `${data.length} points` }
      case 'Quality':
        return { label: 'AVG QUALITY', value: (parseFloat(avg) * 100).toFixed(0) + '%', peak: (parseFloat(max) * 100).toFixed(0) + '%', points: `${data.length} points` }
      default:
        return { label: 'AVERAGE', value: '0', peak: '0', points: '0 points' }
    }
  }

  const getStatsForSensor = calculateStats

  const stats = getStatsForSensor()

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
      <div className="h-48 bg-[#0f1a1e]/30 rounded-lg p-4 fade-in border border-slate-800/50 transition-all duration-300 hover:border-slate-700/75" style={{ animationDelay: '300ms' }}>
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
              dataKey={selectedSensor}
              stroke={getColorForSensor()}
              dot={{ fill: getColorForSensor(), r: 5 }}
              activeDot={{ r: 7 }}
              strokeWidth={2}
              isAnimationActive={true}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}

export default React.memo(SensorChart)
