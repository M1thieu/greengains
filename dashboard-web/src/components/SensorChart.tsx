import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts'
import React from 'react'
import { SENSOR_COLORS } from '../constants/sensors'
import type { FilterState } from '../constants/filters'

interface SensorChartProps {
  selectedSensor: string
  timeRange?: string
  filters?: FilterState
  data?: any[]
}

function SensorChart({ selectedSensor, filters, data: propData }: SensorChartProps) {
  const color = SENSOR_COLORS[selectedSensor] ?? '#10b981'

  const chartData = (propData ?? [])
    .map((point) => {
      const ts = point.timestamp ? new Date(point.timestamp) : null
      const time = ts
        ? `${ts.getHours().toString().padStart(2, '0')}:${ts.getMinutes().toString().padStart(2, '0')}`
        : '—'
      return { time, value: point.value ?? null, fullTimestamp: point.timestamp }
    })
    .filter((point) => {
      if (!filters) return true
      if (selectedSensor === 'Light' && point.value !== null) {
        if (point.value < filters.lightMin || point.value > filters.lightMax) return false
      }
      return true
    })

  const values = chartData.map((d) => d.value).filter((v): v is number => typeof v === 'number')

  const stats = (() => {
    if (values.length === 0) {
      return { label: selectedSensor.toUpperCase(), value: '—', peak: '—', points: '0 pts' }
    }
    const avg = values.reduce((a, b) => a + b, 0) / values.length
    const max = Math.max(...values)
    switch (selectedSensor) {
      case 'Light':
        return { label: 'AVG LIGHT', value: `${avg.toFixed(0)} lux`, peak: `${max.toFixed(0)} lux`, points: `${values.length} pts` }
      case 'Movement':
        return { label: 'AVG MOVEMENT', value: avg.toFixed(3), peak: max.toFixed(3), points: `${values.length} pts` }
      case 'Pressure':
        return { label: 'AVG PRESSURE', value: `${avg.toFixed(2)}°`, peak: `${max.toFixed(2)}°`, points: `${values.length} pts` }
      case 'Quality':
        return { label: 'AVG QUALITY', value: `${(avg * 100).toFixed(0)}%`, peak: `${(max * 100).toFixed(0)}%`, points: `${values.length} pts` }
      default:
        return { label: 'AVERAGE', value: avg.toFixed(2), peak: max.toFixed(2), points: `${values.length} pts` }
    }
  })()

  const gradientId = `sensor-gradient-${selectedSensor}`

  return (
    <div>
      {/* Stats row */}
      <div className="grid grid-cols-3 gap-4 mb-6">
        <div>
          <p className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold">{stats.label}</p>
          <p className="text-2xl font-bold text-white mt-1 tabular-nums">{stats.value}</p>
        </div>
        <div>
          <p className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold">PEAK</p>
          <p className="text-2xl font-bold text-white mt-1 tabular-nums">{stats.peak}</p>
        </div>
        <div>
          <p className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold">POINTS</p>
          <p className="text-2xl font-bold text-white mt-1 tabular-nums">{stats.points}</p>
        </div>
      </div>

      {/* Chart */}
      <div className="h-48 rounded-lg border border-slate-800/50">
        {chartData.length === 0 ? (
          <div className="h-full flex flex-col items-center justify-center text-slate-600">
            <p className="text-sm">No data for this time range</p>
            <p className="text-xs mt-1">Adjust filters or select a wider window</p>
          </div>
        ) : (
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={chartData} margin={{ top: 8, right: 4, left: -24, bottom: 0 }}>
              <defs>
                <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor={color} stopOpacity={0.18} />
                  <stop offset="95%" stopColor={color} stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" vertical={false} />
              <XAxis
                dataKey="time"
                stroke="#334155"
                tick={{ fill: '#64748b', fontSize: 11 }}
                tickLine={false}
                axisLine={false}
                interval="preserveStartEnd"
              />
              <YAxis
                stroke="#334155"
                tick={{ fill: '#64748b', fontSize: 11 }}
                tickLine={false}
                axisLine={false}
                width={48}
              />
              <Tooltip
                contentStyle={{
                  background: '#0d1821',
                  border: '1px solid #1e293b',
                  borderRadius: '6px',
                  fontSize: '12px',
                  boxShadow: '0 4px 16px rgba(0,0,0,0.4)',
                }}
                labelStyle={{ color: '#94a3b8', marginBottom: '2px' }}
                itemStyle={{ color: color }}
                cursor={{ stroke: color, strokeWidth: 1, strokeDasharray: '4 4' }}
              />
              <Area
                type="monotone"
                dataKey="value"
                stroke={color}
                strokeWidth={1.5}
                fill={`url(#${gradientId})`}
                dot={false}
                activeDot={{ r: 4, fill: color, strokeWidth: 0 }}
                isAnimationActive={false}
              />
            </AreaChart>
          </ResponsiveContainer>
        )}
      </div>
    </div>
  )
}

export default React.memo(SensorChart)
