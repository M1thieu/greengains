interface FilterState {
  qualityMin: number
  qualityMax: number
  lightMin: number
  lightMax: number
  minDevices: number
}

interface CoverageItem {
  geohash: string
  samples_count: number
  device_hours: number
  avg_light: number | null
  quality_valid_ratio: number | null
  last_seen: string
}

interface CoverageMapProps {
  filters?: FilterState
  data?: CoverageItem[]
  isLoading?: boolean
}

export default function CoverageMap({ filters, data, isLoading }: CoverageMapProps) {
  // Apply minimum devices filter to coverage data
  const coverageData = (data || []).filter((item) => {
    if (!filters) return true
    // device_hours is roughly proportional to device count, use as proxy
    return item.device_hours >= filters.minDevices
  })

  const colorForPct = (pct: number) =>
    pct >= 80 ? '#10b981' : pct >= 60 ? '#eab308' : '#ef4444'

  return (
    <div>
      {/* Map placeholder */}
      <div
        className="h-48 rounded-lg flex flex-col items-center justify-center mb-6 fade-in border border-slate-800/50 transition-all duration-300 hover:border-slate-700/75 group cursor-pointer"
        style={{ background: '#0b111c' }}
      >
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#334155" strokeWidth="1.5" className="mb-2 group-hover:stroke-slate-400 transition-colors duration-300">
          <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7z"/>
          <circle cx="12" cy="9" r="2.5"/>
        </svg>
        <p className="text-[11px] text-slate-500 font-medium group-hover:text-slate-400 transition-colors duration-300">Interactive Heatmap</p>
        <p className="text-[10px] text-slate-700 mt-1 group-hover:text-slate-600 transition-colors duration-300">Coming soon</p>
      </div>

      {/* Coverage list */}
      <div className="space-y-3">
        {isLoading ? (
          <div className="text-center text-slate-400 py-8">
            <p className="text-sm">Loading coverage data...</p>
          </div>
        ) : coverageData.length === 0 ? (
          <div className="text-center text-slate-400 py-8">
            <p className="text-sm">No coverage data available</p>
            <p className="text-xs mt-1 text-slate-500">No sensors have reported in this time range</p>
          </div>
        ) : (
          coverageData.map((item, idx) => {
            const quality = item.quality_valid_ratio || 0
            const qualityPct = Math.round(quality * 100)

            return (
              <div
                key={item.geohash}
                className="rounded-lg p-4 slide-in-up border border-slate-800/50 hover:border-[#10b981]/40 transition-all duration-300 cursor-pointer group"
                style={{
                  background: '#0b111c',
                  animationDelay: `${idx * 100}ms`,
                }}
                onMouseEnter={(e) => {
                  const el = e.currentTarget as HTMLElement
                  el.style.boxShadow = '0 4px 12px rgba(16, 185, 129, 0.15)'
                  el.style.transform = 'translateY(-2px)'
                }}
                onMouseLeave={(e) => {
                  const el = e.currentTarget as HTMLElement
                  el.style.boxShadow = 'none'
                  el.style.transform = 'translateY(0)'
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
                    <span className="text-sm text-slate-300 font-medium truncate">
                      {new Date(item.last_seen).toLocaleDateString()}
                    </span>
                  </div>
                  <span
                    className="text-xs font-bold flex-shrink-0 ml-2"
                    style={{ color: colorForPct(qualityPct) }}
                  >
                    {qualityPct}%
                  </span>
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
                  {(item.samples_count / 1000).toFixed(1)}K samples · {item.device_hours.toFixed(1)}h device coverage
                </p>
              </div>
            )
          })
        )}
      </div>
    </div>
  )
}
