import { useTranslation } from 'react-i18next'
import type { CoverageItem } from '../api'

interface Props {
  coverageData: CoverageItem[]
  activeSensorCount: number
  appliedGeohash: string
  timeRange: string
  isExporting: boolean
  onExportCsv: () => void
  onZoneClick: (geohash: string) => void   // sets geohash + navigates to Overview
  onZoneClear: () => void                  // clears applied zone filter
}

export default function NetworkTab({
  coverageData, activeSensorCount,
  appliedGeohash, timeRange,
  isExporting, onExportCsv,
  onZoneClick, onZoneClear,
}: Props) {
  const { t } = useTranslation()
  const totalHours = coverageData.reduce((s, c) => s + (c.device_hours || 0), 0)

  return (
    <div className="space-y-3 fade-in">

      {/* Summary stats */}
      <div className="grid grid-cols-3 gap-4">
        <div className="card-elevated rounded-lg p-5" style={{ borderLeft: '3px solid #fbbf24' }}>
          <p className="text-xs text-slate-500 uppercase tracking-widest">{t('network.contributors')}</p>
          <p className="text-3xl font-bold text-white mt-1.5">{activeSensorCount || '—'}</p>
          <p className="text-xs text-slate-600 mt-1">{t('network.activeIn', { range: timeRange })}</p>
        </div>
        <div className="card-elevated rounded-lg p-5" style={{ borderLeft: '3px solid #0ea5e9' }}>
          <p className="text-xs text-slate-500 uppercase tracking-widest">{t('network.zonesMapped')}</p>
          <p className="text-3xl font-bold text-white mt-1.5">{coverageData.length || '—'}</p>
          <p className="text-xs text-slate-600 mt-1">{t('network.geohashAreas')}</p>
        </div>
        <div className="card-elevated rounded-lg p-5" style={{ borderLeft: '3px solid #14b8a6' }}>
          <p className="text-xs text-slate-500 uppercase tracking-widest">{t('network.deviceHours')}</p>
          <p className="text-3xl font-bold text-white mt-1.5">
            {coverageData.length > 0 ? totalHours.toFixed(1) : '—'}
          </p>
          <p className="text-xs text-slate-600 mt-1">{t('network.totalLogged')}</p>
        </div>
      </div>

      {/* Zone coverage table */}
      <div className="card-elevated rounded-lg overflow-hidden">
        <div className="px-5 py-3 border-b border-slate-800 flex items-center justify-between">
          <div>
            <h2 className="text-sm font-semibold text-white">{t('network.coverageByZone')}</h2>
            <p className="text-xs text-slate-400 mt-0.5">{t('network.sortedBy', { range: timeRange })}</p>
          </div>
          <button
            onClick={onExportCsv}
            disabled={isExporting}
            className="px-3 py-1.5 bg-slate-700 hover:bg-slate-600 text-xs text-slate-300 rounded transition-all duration-200 disabled:opacity-60"
          >
            {isExporting ? t('network.exporting') : t('network.exportCsv')}
          </button>
        </div>

        {coverageData.length === 0 ? (
          <div className="px-6 py-8 text-center text-sm text-slate-600">{t('network.noData')}</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead>
                <tr className="border-b border-slate-800/60">
                  <th className="px-5 py-2.5 text-left text-[10px] text-slate-500 uppercase tracking-wider">{t('network.colZone')}</th>
                  <th className="px-5 py-2.5 text-right text-[10px] text-slate-500 uppercase tracking-wider">{t('network.colSamples')}</th>
                  <th className="px-5 py-2.5 text-right text-[10px] text-slate-500 uppercase tracking-wider">{t('network.colQuality')}</th>
                  <th className="px-5 py-2.5 text-right text-[10px] text-slate-500 uppercase tracking-wider">{t('network.colDeviceH')}</th>
                  <th className="px-5 py-2.5 text-right text-[10px] text-slate-500 uppercase tracking-wider">{t('network.colLastActive')}</th>
                  <th className="px-6 py-3" />
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/40">
                {[...coverageData]
                  .sort((a, b) => b.samples_count - a.samples_count)
                  .slice(0, 20)
                  .map((zone) => {
                    const quality = zone.quality_valid_ratio
                    const qualityColor = quality == null ? 'text-slate-600'
                      : quality >= 0.8 ? 'text-[#10b981]'
                      : quality >= 0.6 ? 'text-[#fbbf24]'
                      : 'text-red-400'

                    const ageH = (Date.now() - new Date(zone.last_seen).getTime()) / 3_600_000
                    const freshnessColor = ageH < 1 ? '#10b981' : ageH < 24 ? '#fbbf24' : '#475569'
                    const freshnessTitle = ageH < 1 ? t('network.activeRecent')
                      : ageH < 24 ? t('network.lastSeenH', { h: Math.floor(ageH) })
                      : t('network.lastSeenD', { d: Math.floor(ageH / 24) })

                    const isActive = appliedGeohash === zone.geohash

                    return (
                      <tr
                        key={zone.geohash}
                        onClick={() => isActive ? onZoneClear() : onZoneClick(zone.geohash)}
                        className={`group cursor-pointer transition-colors ${
                          isActive ? 'bg-[#10b981]/10 hover:bg-[#10b981]/15' : 'hover:bg-slate-800/30'
                        }`}
                        title={isActive ? t('network.clearZone') : t('network.drillZone', { geohash: zone.geohash })}
                      >
                        <td className="px-5 py-2 font-mono text-slate-300">
                          <span className="flex items-center gap-2">
                            <span
                              className="inline-block h-2 w-2 rounded-full flex-shrink-0"
                              style={{ background: freshnessColor }}
                              title={freshnessTitle}
                            />
                            {zone.geohash}
                            {isActive && <span className="text-[9px] font-bold text-[#10b981]">{t('network.active')}</span>}
                          </span>
                        </td>
                        <td className="px-5 py-2 text-right tabular-nums text-slate-300">
                          {zone.samples_count.toLocaleString()}
                        </td>
                        <td className={`px-6 py-2.5 text-right tabular-nums font-medium ${qualityColor}`}>
                          {quality != null ? `${(quality * 100).toFixed(0)}%` : '—'}
                        </td>
                        <td className="px-5 py-2 text-right tabular-nums text-slate-400">
                          {(zone.device_hours || 0).toFixed(1)}
                        </td>
                        <td className="px-5 py-2 text-right text-slate-500" title={freshnessTitle}>
                          {new Date(zone.last_seen).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })}
                        </td>
                        <td className="px-4 py-2 text-right">
                          <span className="text-[10px] text-slate-700 group-hover:text-slate-300 transition-colors">
                            {isActive ? '×' : '→'}
                          </span>
                        </td>
                      </tr>
                    )
                  })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
