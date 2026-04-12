import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import type { FilterState } from '../constants/filters'
import type { CoverageItem } from '../api'

interface CoverageMapProps {
  filters?: FilterState
  data?: CoverageItem[]
  isLoading?: boolean
  selectedGeohash?: string
  onZoneSelect?: (geohash: string) => void
}

export default function CoverageMap({ filters, data, isLoading, selectedGeohash, onZoneSelect }: CoverageMapProps) {
  const { t } = useTranslation()
  const [localSelected, setLocalSelected] = useState<string | null>(null)
  const activeZone = selectedGeohash ?? localSelected

  // Apply minimum devices filter to coverage data
  const coverageData = (data || []).filter((item) => {
    if (!filters) return true
    // device_hours is roughly proportional to device count, use as proxy
    return item.device_hours >= filters.minDevices
  })

  const colorForPct = (pct: number) =>
    pct >= 80 ? '#10b981' : pct >= 60 ? '#eab308' : '#ef4444'

  // Summary stats computed from coverage data
  const totalSamples = coverageData.reduce((s, z) => s + z.samples_count, 0)
  const totalHours = coverageData.reduce((s, z) => s + (z.device_hours || 0), 0)
  const qualities = coverageData.map((z) => z.quality_valid_ratio || 0).filter((q) => q > 0)
  const avgQuality = qualities.length ? qualities.reduce((a, b) => a + b, 0) / qualities.length : null
  const goodZones = qualities.filter((q) => q >= 0.8).length
  const warnZones = qualities.filter((q) => q >= 0.6 && q < 0.8).length
  const poorZones = qualities.filter((q) => q < 0.6).length

  return (
    <div>
      {/* Quality distribution summary */}
      {coverageData.length > 0 && (
        <div className="rounded-lg p-4 border border-slate-800/50 mb-5 fade-in" style={{ background: '#0b111c' }}>
          {/* 4-stat grid */}
          <div className="grid grid-cols-2 gap-x-4 gap-y-3 mb-4">
            <div>
              <p className="text-[9px] text-slate-600 uppercase tracking-wider">{t('coverageMap.zones')}</p>
              <p className="text-lg font-bold text-white mt-0.5 tabular-nums">{coverageData.length}</p>
            </div>
            <div>
              <p className="text-[9px] text-slate-600 uppercase tracking-wider">{t('coverageMap.avgQuality')}</p>
              <p className="text-lg font-bold mt-0.5 tabular-nums" style={{ color: avgQuality !== null ? colorForPct(Math.round(avgQuality * 100)) : '#475569' }}>
                {avgQuality !== null ? `${Math.round(avgQuality * 100)}%` : '—'}
              </p>
            </div>
            <div>
              <p className="text-[9px] text-slate-600 uppercase tracking-wider">{t('coverageMap.totalSamples')}</p>
              <p className="text-lg font-bold text-white mt-0.5 tabular-nums">
                {totalSamples >= 1000 ? `${(totalSamples / 1000).toFixed(1)}K` : totalSamples}
              </p>
            </div>
            <div>
              <p className="text-[9px] text-slate-600 uppercase tracking-wider">{t('coverageMap.deviceHours')}</p>
              <p className="text-lg font-bold text-white mt-0.5 tabular-nums">{totalHours.toFixed(1)}h</p>
            </div>
          </div>
          {/* Quality distribution stacked bar + legend */}
          <p className="text-[9px] text-slate-700 uppercase tracking-wider mb-1.5">{t('coverageMap.qualityBreakdown')}</p>
          <div className="h-1.5 rounded-full overflow-hidden flex gap-px">
            {goodZones > 0 && <div className="bg-[#10b981]" style={{ flex: goodZones }} />}
            {warnZones > 0 && <div className="bg-[#fbbf24]" style={{ flex: warnZones }} />}
            {poorZones > 0 && <div className="bg-red-500" style={{ flex: poorZones }} />}
          </div>
          <div className="flex gap-3 mt-1.5 text-[9px]">
            {goodZones > 0 && <span className="text-[#10b981]">{t('coverageMap.good', { count: goodZones })}</span>}
            {warnZones > 0 && <span className="text-[#fbbf24]">{t('coverageMap.warn', { count: warnZones })}</span>}
            {poorZones > 0 && <span className="text-red-400">{t('coverageMap.poor', { count: poorZones })}</span>}
          </div>
        </div>
      )}

      {/* Active zone filter chip */}
      {activeZone && (
        <div className="flex items-center gap-2 mb-3">
          <span className="text-[10px] text-slate-500 uppercase tracking-wider">{t('coverageMap.filteringBy')}</span>
          <code className="text-xs font-mono px-2 py-0.5 rounded text-[#10b981] bg-[#10b981]/10 border border-[#10b981]/20">
            {activeZone}
          </code>
          <button
            onClick={() => { setLocalSelected(null); if (onZoneSelect) onZoneSelect('') }}
            className="text-[10px] text-slate-500 hover:text-slate-300 transition-colors"
          >
            ✕ {t('coverageMap.clearZone')}
          </button>
        </div>
      )}

      {/* Coverage list */}
      <div className="space-y-3">
        {isLoading ? (
          <div className="text-center text-slate-400 py-8">
            <p className="text-sm">{t('coverageMap.loading')}</p>
          </div>
        ) : coverageData.length === 0 ? (
          <div className="text-center text-slate-500 py-12">
            <svg className="w-12 h-12 mx-auto mb-3 text-slate-600 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 20l-5.447-2.724A1 1 0 003 16.382V5.618a1 1 0 011.553-.894L9 7.5m0 0l6.553-3.276A1 1 0 0117 5.618v10.764a1 1 0 01-1.553.894L9 12.5m0 0V20" />
            </svg>
            <p className="text-sm font-medium">{t('coverageMap.emptyTitle')}</p>
            <p className="text-xs mt-2 text-slate-600">{t('coverageMap.emptyHint')}</p>
          </div>
        ) : (
          coverageData.map((item, idx) => {
            const quality = item.quality_valid_ratio || 0
            const qualityPct = Math.round(quality * 100)
            const isSelected = activeZone === item.geohash

            const handleClick = () => {
              const next = isSelected ? null : item.geohash
              setLocalSelected(next)
              if (onZoneSelect) onZoneSelect(next ?? '')
            }

            return (
              <div
                key={item.geohash}
                onClick={handleClick}
                className={`rounded-lg p-4 slide-in-up border transition-all duration-200 cursor-pointer group ${
                  isSelected
                    ? 'border-[#10b981]/60 bg-[#10b981]/5'
                    : 'border-slate-800/50 hover:border-[#10b981]/30'
                }`}
                style={{
                  background: isSelected ? 'rgba(16,185,129,0.06)' : '#0b111c',
                  animationDelay: `${idx * 60}ms`,
                }}
              >
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2 min-w-0">
                    <code
                      className="text-xs font-mono px-2 py-1 rounded flex-shrink-0"
                      style={{ color: '#10b981', background: '#10b98115' }}
                    >
                      {item.geohash}
                    </code>
                    <span className="text-xs text-slate-500 truncate">
                      {(() => {
                        const diffMs = Date.now() - new Date(item.last_seen).getTime()
                        const diffH = Math.floor(diffMs / 3_600_000)
                        const diffD = Math.floor(diffH / 24)
                        if (diffH < 1) return '< 1h ago'
                        if (diffH < 24) return `${diffH}h ago`
                        return `${diffD}d ago`
                      })()}
                    </span>
                  </div>
                  <div className="flex items-center gap-2 flex-shrink-0 ml-2">
                    {isSelected && (
                      <span className="text-[9px] text-[#10b981] font-semibold uppercase tracking-wider border border-[#10b981]/30 rounded px-1.5 py-0.5">
                        {t('coverageMap.active')}
                      </span>
                    )}
                    <span
                      className="text-xs font-bold"
                      style={{ color: colorForPct(qualityPct) }}
                    >
                      {qualityPct}%
                    </span>
                  </div>
                </div>

                {/* Coverage bar */}
                <div className="h-px bg-slate-800/50 rounded-full overflow-hidden mb-2">
                  <div
                    className="h-full rounded-full transition-all duration-700 ease-out"
                    style={{
                      width: `${qualityPct}%`,
                      background: colorForPct(qualityPct),
                      boxShadow: `0 0 8px ${colorForPct(qualityPct)}40`,
                    }}
                  />
                </div>

                <p className="text-xs text-slate-600">
                  {t('coverageMap.zoneRow', {
                    samples: (item.samples_count / 1000).toFixed(1),
                    hours: item.device_hours.toFixed(1),
                  })}
                </p>
              </div>
            )
          })
        )}
      </div>
    </div>
  )
}
