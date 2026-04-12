import { useState, useRef } from 'react'
import { useTranslation } from 'react-i18next'
import SensorChart from './SensorChart'
import CoverageMap from './CoverageMap'
import FilterPanel from './FilterPanel'
import { ChartSkeleton, CoverageSkeleton } from './LoadingSkeleton'
import { SENSORS } from '../constants/sensors'
import { dateRangeLabel } from '../utils/date'
import type { FilterState } from '../constants/filters'
import type { CoverageItem } from '../api'

interface Props {
  isInitialLoad: boolean
  selectedSensor: string
  setSelectedSensor: (v: string) => void
  timeRange: string
  filters: FilterState
  activeFilterCount: number
  onFilterApply: (f: FilterState) => void
  onFilterReset: () => void
  sensorReadings: any[]
  isLoading: boolean
  isExporting: boolean
  onExportCsv: () => void
  coverageData: CoverageItem[]
  isCoverageLoading: boolean
}

/**
 * Overview tab: 2/3 sensor chart + 1/3 coverage sidebar.
 * Owns its own filter panel open/close state and button ref (no prop drilling needed).
 */
export default function OverviewTab({
  isInitialLoad,
  selectedSensor, setSelectedSensor,
  timeRange,
  filters, activeFilterCount, onFilterApply, onFilterReset,
  sensorReadings, isLoading,
  isExporting, onExportCsv,
  coverageData, isCoverageLoading,
}: Props) {
  const { t } = useTranslation()
  const [isFilterPanelOpen, setIsFilterPanelOpen] = useState(false)
  const filterButtonRef = useRef<HTMLButtonElement>(null)

  if (isInitialLoad) {
    return (
      <div className="grid grid-cols-3 gap-4">
        <ChartSkeleton />
        <CoverageSkeleton />
      </div>
    )
  }

  return (
    <div className="grid grid-cols-3 gap-6">

      {/* Sensor chart — 2/3 width */}
      <div className="col-span-2 rounded-lg overflow-hidden card-premium transition-all duration-300 group">
        <div className="flex items-center justify-between px-5 py-3 border-b border-slate-800">
          <div>
            <h2 className="text-sm font-semibold text-white">{t('overview.sensorData')}</h2>
            <p className="text-xs text-slate-400 mt-0.5">{t('overview.telemetry', { range: dateRangeLabel(timeRange) })}</p>
          </div>
          <div className="flex gap-2 relative">
            <button
              onClick={onExportCsv}
              disabled={isExporting}
              className="px-3 py-1.5 bg-slate-700 hover:bg-slate-600 active:bg-slate-800 text-xs text-slate-300 rounded transition-all duration-200 hover:text-slate-100 active:scale-95 cursor-pointer disabled:opacity-60 disabled:cursor-not-allowed"
            >
              {isExporting ? t('overview.exporting') : t('overview.exportCsv')}
            </button>
            <div className="relative">
              <button
                ref={filterButtonRef}
                onClick={() => setIsFilterPanelOpen((v) => !v)}
                className={`px-3 py-1.5 text-xs font-medium rounded transition-all duration-200 active:scale-95 cursor-pointer flex items-center gap-1.5 ${
                  activeFilterCount > 0
                    ? 'bg-[#10b981]/20 hover:bg-[#10b981]/30 text-[#10b981] border border-[#10b981]/30'
                    : 'bg-slate-700 hover:bg-slate-600 text-slate-300 hover:text-slate-100'
                }`}
              >
                {t('overview.filters')}
                {activeFilterCount > 0 && (
                  <span className="inline-flex items-center justify-center w-5 h-5 text-[10px] font-bold rounded-full bg-[#10b981]/30 border border-[#10b981]/50">
                    {activeFilterCount}
                  </span>
                )}
              </button>
              <FilterPanel
                filters={filters}
                isOpen={isFilterPanelOpen}
                onClose={() => setIsFilterPanelOpen(false)}
                onApply={onFilterApply}
                onReset={onFilterReset}
              />
            </div>
          </div>
        </div>

        {/* Sensor type tabs */}
        <div className="flex border-b border-slate-800 px-6">
          {Object.values(SENSORS).map((tab) => (
            <button
              key={tab.name}
              onClick={() => setSelectedSensor(tab.name)}
              className={`px-5 py-3.5 text-sm font-semibold border-b-2 transition-all duration-300 mr-1 ${
                selectedSensor === tab.name ? 'text-white' : 'text-slate-500 hover:text-slate-400'
              }`}
              style={{
                borderBottomColor: selectedSensor === tab.name ? tab.color : 'transparent',
                color: selectedSensor === tab.name ? tab.color : undefined,
              }}
            >
              {t(`sensors.${tab.name.toLowerCase()}`)}
            </button>
          ))}
        </div>

        <div className="p-5">
          <SensorChart
            selectedSensor={selectedSensor}
            timeRange={timeRange}
            filters={filters}
            data={sensorReadings}
            isLoading={isLoading}
          />
        </div>
      </div>

      {/* Coverage sidebar — 1/3 width */}
      <div className="rounded-lg overflow-hidden card-premium transition-all duration-300">
        <div className="px-5 py-3 border-b border-slate-800">
          <h2 className="text-sm font-semibold text-white">{t('overview.coverageTitle')}</h2>
          <p className="text-xs text-slate-400 mt-0.5">{t('overview.coverageZones', { count: coverageData.length })}</p>
        </div>
        <div className="p-3">
          <CoverageMap filters={filters} data={coverageData} isLoading={isCoverageLoading} />
        </div>
      </div>

    </div>
  )
}
