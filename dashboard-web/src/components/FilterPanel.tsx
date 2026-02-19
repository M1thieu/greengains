import { useState } from 'react'
import * as Slider from '@radix-ui/react-slider'
import { type FilterState, DEFAULT_FILTERS } from '../constants/filters'

// Re-export so existing `import { FilterState } from './FilterPanel'` keeps working
export type { FilterState }

interface FilterPanelProps {
  filters: FilterState
  isOpen: boolean
  onClose: () => void
  onApply: (filters: FilterState) => void
  onReset: () => void
}

export default function FilterPanel({
  filters,
  isOpen,
  onClose,
  onApply,
  onReset,
}: FilterPanelProps) {
  const [localFilters, setLocalFilters] = useState(filters)

  const handleApply = () => {
    onApply(localFilters)
    onClose()
  }

  const handleReset = () => {
    setLocalFilters(DEFAULT_FILTERS)
    onReset()
    onClose()
  }

  if (!isOpen) return null

  return (
    <>
      {/* Backdrop */}
      <div
        className="fixed inset-0 z-40 opacity-0"
        onClick={onClose}
      />

      {/* Panel */}
      <div className="absolute top-full right-0 mt-2 w-80 bg-[#0d1821] border border-slate-700 rounded-lg shadow-2xl z-50 overflow-hidden fade-in"
        style={{
          background: 'linear-gradient(135deg, rgba(13, 24, 33, 0.95) 0%, rgba(15, 31, 46, 0.95) 100%)',
          boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.3), 0 10px 10px -5px rgba(16, 185, 129, 0.1)',
        }}
      >
        <div className="p-5 space-y-5">
          {/* Quality Range */}
          <div>
            <label className="text-xs font-semibold text-slate-300 uppercase tracking-wider block mb-3">
              Quality Range
            </label>
            <div className="space-y-2">
              <Slider.Root
                className="relative flex items-center select-none touch-none w-full h-5"
                value={[localFilters.qualityMin, localFilters.qualityMax]}
                onValueChange={(value) =>
                  setLocalFilters((prev) => ({
                    ...prev,
                    qualityMin: value[0],
                    qualityMax: value[1],
                  }))
                }
                min={0}
                max={1}
                step={0.05}
              >
                <Slider.Track className="relative grow rounded-full h-2 bg-slate-800">
                  <Slider.Range className="absolute rounded-full h-full bg-gradient-to-r from-[#fbbf24] to-[#10b981]" />
                </Slider.Track>
                <Slider.Thumb
                  className="block h-5 w-5 rounded-full border-2 border-slate-700 bg-[#10b981] hover:bg-[#14b8a6] transition-colors focus:outline-none focus:ring-2 focus:ring-[#10b981]/50"
                  aria-label="Quality min"
                />
                <Slider.Thumb
                  className="block h-5 w-5 rounded-full border-2 border-slate-700 bg-[#10b981] hover:bg-[#14b8a6] transition-colors focus:outline-none focus:ring-2 focus:ring-[#10b981]/50"
                  aria-label="Quality max"
                />
              </Slider.Root>
              <div className="flex justify-between text-xs text-slate-400">
                <span>{localFilters.qualityMin.toFixed(2)}</span>
                <span>{localFilters.qualityMax.toFixed(2)}</span>
              </div>
            </div>
          </div>

          {/* Light Range */}
          <div>
            <label className="text-xs font-semibold text-slate-300 uppercase tracking-wider block mb-3">
              Light Range (lux)
            </label>
            <div className="space-y-2">
              <Slider.Root
                className="relative flex items-center select-none touch-none w-full h-5"
                value={[localFilters.lightMin, localFilters.lightMax]}
                onValueChange={(value) =>
                  setLocalFilters((prev) => ({
                    ...prev,
                    lightMin: value[0],
                    lightMax: value[1],
                  }))
                }
                min={0}
                max={1000}
                step={10}
              >
                <Slider.Track className="relative grow rounded-full h-2 bg-slate-800">
                  <Slider.Range className="absolute rounded-full h-full bg-gradient-to-r from-[#fbbf24] to-[#14b8a6]" />
                </Slider.Track>
                <Slider.Thumb
                  className="block h-5 w-5 rounded-full border-2 border-slate-700 bg-[#fbbf24] hover:bg-[#fcd34d] transition-colors focus:outline-none focus:ring-2 focus:ring-[#fbbf24]/50"
                  aria-label="Light min"
                />
                <Slider.Thumb
                  className="block h-5 w-5 rounded-full border-2 border-slate-700 bg-[#fbbf24] hover:bg-[#fcd34d] transition-colors focus:outline-none focus:ring-2 focus:ring-[#fbbf24]/50"
                  aria-label="Light max"
                />
              </Slider.Root>
              <div className="flex justify-between text-xs text-slate-400">
                <span>{localFilters.lightMin} lux</span>
                <span>{localFilters.lightMax} lux</span>
              </div>
            </div>
          </div>

          {/* Minimum Devices */}
          <div>
            <label className="text-xs font-semibold text-slate-300 uppercase tracking-wider block mb-3">
              Minimum Devices
            </label>
            <div className="space-y-2">
              <Slider.Root
                className="relative flex items-center select-none touch-none w-full h-5"
                value={[localFilters.minDevices]}
                onValueChange={(value) =>
                  setLocalFilters((prev) => ({
                    ...prev,
                    minDevices: value[0],
                  }))
                }
                min={1}
                max={10}
                step={1}
              >
                <Slider.Track className="relative grow rounded-full h-2 bg-slate-800">
                  <Slider.Range className="absolute rounded-full h-full bg-[#0ea5e9]" />
                </Slider.Track>
                <Slider.Thumb
                  className="block h-5 w-5 rounded-full border-2 border-slate-700 bg-[#0ea5e9] hover:bg-[#06b6d4] transition-colors focus:outline-none focus:ring-2 focus:ring-[#0ea5e9]/50"
                  aria-label="Minimum devices"
                />
              </Slider.Root>
              <div className="text-xs text-slate-400">≥ {localFilters.minDevices} devices</div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="border-t border-slate-700/60 px-5 py-3 flex gap-2 bg-slate-900/30">
          <button
            onClick={handleApply}
            className="flex-1 px-3 py-1.5 bg-[#10b981] hover:bg-[#059669] active:bg-[#047857] text-white text-xs font-semibold rounded transition-all duration-200 hover:shadow-md active:scale-95"
          >
            Apply
          </button>
          <button
            onClick={handleReset}
            className="px-3 py-1.5 bg-slate-700 hover:bg-slate-600 text-slate-300 text-xs font-semibold rounded transition-all duration-200 hover:shadow-md active:scale-95"
          >
            Reset
          </button>
        </div>
      </div>
    </>
  )
}
