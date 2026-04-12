import { useTranslation } from 'react-i18next'

interface Props {
  timeRange: string
  setTimeRange: (v: string) => void
  bucket: string
  setBucket: (v: string) => void
  geohash: string
  setGeohash: (v: string) => void
  appliedGeohash: string
  setAppliedGeohash: (v: string) => void
  isLoading: boolean
  sensorReadings: any[]
  selectedSensor: string
  onApply: () => void
}

/** Top filter bar: range buttons, bucket selector, geohash input, apply, active zone chip. */
export default function FilterBar({
  timeRange, setTimeRange,
  bucket, setBucket,
  geohash, setGeohash,
  appliedGeohash, setAppliedGeohash,
  isLoading, sensorReadings, selectedSensor,
  onApply,
}: Props) {
  const { t } = useTranslation()

  const handleRangeClick = (r: string) => {
    setTimeRange(r)
    onApply()
  }

  const handleBucketChange = (v: string) => {
    setBucket(v)
    onApply()
  }

  const clearZone = () => {
    setGeohash('')
    setAppliedGeohash('')
  }

  return (
    <div className="flex items-center gap-2 py-1.5 border-t border-slate-800/40">
      <span className="text-[10px] text-slate-600 uppercase tracking-wider mr-0.5">{t('filters.range')}</span>

      {/* Range buttons */}
      <div className="flex gap-0.5">
        {(['24h', '7d', '30d', '90d'] as const).map((r) => {
          const isPro = r === '30d' || r === '90d'
          return (
            <button
              key={r}
              onClick={() => handleRangeClick(r)}
              className={`px-2 py-0.5 rounded text-[11px] transition-all duration-200 font-medium flex items-center gap-1 ${
                timeRange === r
                  ? 'bg-[#10b981] text-white shadow-md active:scale-95'
                  : 'text-slate-500 hover:text-slate-300 hover:bg-slate-800/50 active:scale-95'
              }`}
            >
              {r}
              {isPro && (
                <span className={`text-[8px] font-bold tracking-wide px-0.5 rounded ${
                  timeRange === r ? 'bg-white/20 text-white' : 'bg-slate-700 text-slate-400'
                }`}>{t('common.pro')}</span>
              )}
            </button>
          )
        })}
      </div>

      <div className="border-l border-slate-800 h-3 mx-1" />

      {/* Bucket selector */}
      <select
        value={bucket}
        onChange={(e) => handleBucketChange(e.target.value)}
        className="px-2 py-0.5 bg-transparent border border-slate-800 hover:border-slate-700 focus:border-[#10b981] focus:ring-2 focus:ring-[#10b981]/20 rounded text-[11px] text-slate-400 outline-none transition-all duration-200"
      >
        <option>5 minutes</option>
        <option>1 day</option>
      </select>


      {/* Apply */}
      <button
        onClick={onApply}
        disabled={isLoading}
        className="px-2.5 py-0.5 bg-[#10b981]/10 hover:bg-[#10b981]/20 active:bg-[#10b981]/30 text-[#10b981] rounded text-[11px] font-medium border border-[#10b981]/15 hover:border-[#10b981]/30 transition-all duration-200 hover:shadow-sm disabled:opacity-60 disabled:cursor-not-allowed"
      >
        {isLoading ? t('filters.applying') : t('filters.apply')}
      </button>

      {/* Active zone chip */}
      {appliedGeohash && (
        <button
          onClick={clearZone}
          className="flex items-center gap-1 px-2 py-0.5 bg-[#10b981]/10 border border-[#10b981]/30 rounded text-[11px] text-[#10b981] hover:bg-[#10b981]/20 transition-all"
          title="Clear zone filter"
        >
          <span className="font-mono">{appliedGeohash}</span>
          <span className="text-[10px]">×</span>
        </button>
      )}

      {/* Data point count — subtle density indicator */}
      <span className="ml-auto text-[10px] text-slate-700 tabular-nums">
        {isLoading ? t('filters.loading') : sensorReadings.length > 0 ? t('filters.dataPoints', { count: sensorReadings.length, sensor: selectedSensor }) : ''}
      </span>
    </div>
  )
}
