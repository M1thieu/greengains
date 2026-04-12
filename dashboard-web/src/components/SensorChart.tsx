import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ReferenceLine,
  Label,
  ResponsiveContainer,
} from 'recharts'
import React, { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { SENSOR_COLORS, SENSORS, formatSensorValue, formatSensorYTick } from '../constants/sensors'
import { timeRangeToDays } from '../constants/time-ranges'
import type { FilterState } from '../constants/filters'

/** Linear interpolation percentile — standard method (same as Excel PERCENTILE.INC). */
function pct(arr: number[], p: number): number {
  if (!arr.length) return 0
  const sorted = [...arr].sort((a, b) => a - b)
  const idx = (p / 100) * (sorted.length - 1)
  const lo = Math.floor(idx)
  const hi = Math.ceil(idx)
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (idx - lo)
}

interface SensorChartProps {
  selectedSensor: string
  timeRange?: string
  filters?: FilterState
  data?: any[]
  isLoading?: boolean
}

const hhmm = (d: Date) =>
  `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`

const mmdd = (d: Date) =>
  d.toLocaleDateString('en-GB', { month: 'short', day: 'numeric' })

function formatAxisTick(ms: number, timeRange?: string): string {
  const d = new Date(ms)
  return !timeRange || timeRange === '24h' ? hhmm(d) : mmdd(d)
}

function formatTooltipLabel(ms: number, timeRange?: string): string {
  const d = new Date(ms)
  if (!timeRange || timeRange === '24h') return hhmm(d)
  if (timeRange === '30d' || timeRange === '90d') return mmdd(d)
  return `${mmdd(d)} · ${hhmm(d)}`
}

function SensorChart({ selectedSensor, timeRange, filters, data: propData, isLoading }: SensorChartProps) {
  const { t } = useTranslation()
  const color = SENSOR_COLORS[selectedSensor] ?? '#10b981'
  const meta = SENSORS[selectedSensor]

  // Track hovered data point — enables live scrubbing of values while mousing over the chart.
  const [hovered, setHovered] = useState<{ ts: number; value: number } | null>(null)

  // Clear hover state when switching sensor tabs — otherwise stale value stays until mouse moves.
  useEffect(() => { setHovered(null) }, [selectedSensor])

  const chartData = (propData ?? [])
    .map((point) => ({
      ts: point.timestamp ? new Date(point.timestamp).getTime() : 0,
      value: point.value ?? null,
    }))
    .filter((point) => point.ts > 0)
    .sort((a, b) => a.ts - b.ts)
    .filter((point) => {
      if (!filters) return true
      if (selectedSensor === 'Light' && point.value !== null) {
        if (point.value < filters.lightMin || point.value > filters.lightMax) return false
      }
      return true
    })

  const values = chartData.map((d) => d.value).filter((v): v is number => typeof v === 'number')

  const avg  = values.length ? values.reduce((a, b) => a + b, 0) / values.length : null
  const max  = values.length ? Math.max(...values) : null
  const min  = values.length ? Math.min(...values) : null
  const p95  = values.length >= 2 ? pct(values, 95) : null

  // When scrubbing: first stat shows the hovered point's value + timestamp label.
  // When idle: first stat shows the period average (standard behaviour).
  const liveValue = hovered?.value ?? avg
  const liveLabel = hovered
    ? formatTooltipLabel(hovered.ts, timeRange)
    : (meta ? t('chart.avgSensor', { sensor: t(`sensors.${meta.name.toLowerCase()}`) }).toUpperCase() : t('chart.average'))

  const gradientId = `sensor-gradient-${selectedSensor}`

  const domainEnd = Date.now()
  const domainStart = domainEnd - timeRangeToDays(timeRange ?? '7d') * 86_400_000

  const tickN = !timeRange || timeRange === '24h' ? 6 : timeRange === '7d' ? 7 : 6
  const axisTicks = Array.from({ length: tickN }, (_, i) =>
    Math.round(domainStart + (domainEnd - domainStart) * (i / (tickN - 1)))
  )

  return (
    <div>
      {/* Stats row — live value | P95 | MIN | PEAK | readings count */}
      <div className="flex items-start gap-8 mb-5">
        {/* First stat: scrubs to hovered value while mousing over chart */}
        <div className="min-w-[90px]">
          <p className={`text-[10px] uppercase tracking-widest font-semibold transition-colors duration-150 ${
            hovered ? 'text-slate-400' : 'text-slate-500'
          }`}>
            {liveLabel}
          </p>
          <p className={`text-2xl font-bold mt-1 tabular-nums transition-colors duration-150 ${
            hovered ? 'text-white' : 'text-slate-300'
          }`}>
            {liveValue !== null ? formatSensorValue(selectedSensor, liveValue) : '—'}
          </p>
        </div>
        <div className="w-px self-stretch bg-slate-800 mx-1" />
        <div>
          <p className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold">
            {t('chart.p95')}
            <span className="ml-1 text-slate-700 normal-case font-normal">{t('chart.p95Desc')}</span>
          </p>
          <p className="text-2xl font-bold text-white mt-1 tabular-nums">
            {p95 !== null ? formatSensorValue(selectedSensor, p95) : '—'}
          </p>
        </div>
        <div>
          <p className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold">{t('chart.min')}</p>
          <p className="text-2xl font-bold text-white mt-1 tabular-nums">
            {min !== null ? formatSensorValue(selectedSensor, min) : '—'}
          </p>
        </div>
        <div>
          <p className="text-[10px] text-slate-500 uppercase tracking-widest font-semibold">{t('chart.peak')}</p>
          <p className="text-2xl font-bold text-white mt-1 tabular-nums">
            {max !== null ? formatSensorValue(selectedSensor, max) : '—'}
          </p>
        </div>
        {values.length > 0 && (
          <div className="ml-auto text-right">
            <p className="text-[10px] text-slate-600 uppercase tracking-widest font-semibold">{t('chart.readings')}</p>
            <p className="text-lg font-semibold text-slate-500 mt-1 tabular-nums">
              {values.length >= 1000 ? `${(values.length / 1000).toFixed(1)}K` : values.length}
            </p>
          </div>
        )}
      </div>

      {/* Chart */}
      <div className="relative h-64 rounded-lg border border-slate-800/50">
        {chartData.length === 0 && isLoading ? (
          <div className="h-full flex items-end gap-px px-4 pb-4 animate-pulse">
            {[38, 62, 28, 72, 52, 80, 45, 68, 33, 57, 82, 48].map((h, i) => (
              <div key={i} className="flex-1 bg-slate-800 rounded-t" style={{ height: `${h}%` }} />
            ))}
          </div>
        ) : chartData.length === 0 ? (
          <div className="h-full flex flex-col items-center justify-center gap-2 text-slate-700">
            <svg className="w-8 h-8 opacity-40" fill="none" stroke="currentColor" strokeWidth={1.5} viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" d="M3 13.5l5-5 4 4 5-5 4 4" />
              <path strokeLinecap="round" strokeLinejoin="round" d="M3 19h18" opacity={0.4} />
            </svg>
            <p className="text-sm">{t('chart.noData')}</p>
            <p className="text-xs text-slate-600">{t('chart.noDataHint')}</p>
          </div>
        ) : (
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart
              data={chartData}
              margin={{ top: 8, right: 4, left: -20, bottom: 0 }}
              onMouseMove={(e: any) => {
                if (e?.activePayload?.length && e.activePayload[0]?.value != null) {
                  setHovered({ ts: e.activePayload[0].payload.ts, value: e.activePayload[0].value })
                }
              }}
              onMouseLeave={() => setHovered(null)}
            >
              <defs>
                <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor={color} stopOpacity={0.15} />
                  <stop offset="95%" stopColor={color} stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" vertical={false} />
              <XAxis
                dataKey="ts"
                type="number"
                scale="time"
                domain={[domainStart, domainEnd]}
                ticks={axisTicks}
                stroke="#334155"
                tick={{ fill: '#64748b', fontSize: 11 }}
                tickLine={false}
                axisLine={false}
                tickFormatter={(ms: number) => formatAxisTick(ms, timeRange)}
              />
              <YAxis
                stroke="#334155"
                tick={{ fill: '#64748b', fontSize: 11 }}
                tickLine={false}
                axisLine={false}
                width={44}
                domain={[0, 'auto']}
                allowDecimals={meta?.yAllowDecimals ?? false}
                tickCount={5}
                tickFormatter={(v: number) => formatSensorYTick(selectedSensor, v)}
              />
              {/* Average reference line — shows where the period average sits */}
              {avg !== null && (
                <ReferenceLine y={avg} stroke={color} strokeOpacity={0.3} strokeDasharray="5 4" strokeWidth={1}>
                  <Label
                    value={`avg ${formatSensorValue(selectedSensor, avg)}`}
                    position="insideTopRight"
                    style={{ fontSize: 9, fill: color, opacity: 0.5 }}
                  />
                </ReferenceLine>
              )}
              {/* P95 reference line — shows the 95th percentile ceiling */}
              {p95 !== null && avg !== null && Math.abs(p95 - avg) > avg * 0.05 && (
                <ReferenceLine y={p95} stroke={color} strokeOpacity={0.12} strokeDasharray="2 5" strokeWidth={1} />
              )}
              <Tooltip
                isAnimationActive={false}
                cursor={{ stroke: color, strokeWidth: 1, strokeDasharray: '4 4' }}
                content={({ active, payload, label }) => {
                  if (!active || !payload?.length || payload[0]?.value == null) return null
                  return (
                    <div style={{
                      background: '#0d1821',
                      border: '1px solid #1e293b',
                      borderRadius: 6,
                      padding: '8px 12px',
                      fontSize: 12,
                      boxShadow: '0 4px 16px rgba(0,0,0,0.4)',
                      pointerEvents: 'none',
                    }}>
                      <p style={{ color: '#94a3b8', marginBottom: 4, fontSize: 11 }}>
                        {formatTooltipLabel(label as number, timeRange)}
                      </p>
                      <p style={{ color, fontWeight: 600 }}>
                        {formatSensorValue(selectedSensor, payload[0].value as number)}
                      </p>
                    </div>
                  )
                }}
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
                connectNulls={false}
              />
            </AreaChart>
          </ResponsiveContainer>
        )}
        {/* Dim overlay: background refresh in progress — existing chart stays visible, signals "updating" */}
        {isLoading && chartData.length > 0 && (
          <div className="absolute inset-0 rounded-lg bg-slate-900/40 pointer-events-none transition-opacity duration-300" />
        )}
      </div>
    </div>
  )
}

export default React.memo(SensorChart)
