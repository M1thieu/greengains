import { useState, useEffect } from 'react'

interface Command {
  id: string
  label: string
  description: string
  shortcut?: string
  action: () => void
  category: 'Navigation' | 'Sensors' | 'Filters' | 'Export'
}

interface CommandPaletteProps {
  isOpen: boolean
  onClose: () => void
  commands: Command[]
  onSelectSensor?: (sensor: string) => void
  onChangeTimeRange?: (range: string) => void
}

export default function CommandPalette({
  isOpen,
  onClose,
  commands,
  onSelectSensor,
  onChangeTimeRange,
}: CommandPaletteProps) {
  const [search, setSearch] = useState('')
  const [selectedIndex, setSelectedIndex] = useState(0)

  const filtered = commands.filter((cmd) =>
    cmd.label.toLowerCase().includes(search.toLowerCase()) ||
    cmd.description.toLowerCase().includes(search.toLowerCase())
  )

  // Reset selection when search changes
  useEffect(() => {
    setSelectedIndex(0)
  }, [search])

  // Handle keyboard navigation
  useEffect(() => {
    if (!isOpen) return

    const handleKeyDown = (e: KeyboardEvent) => {
      switch (e.key) {
        case 'ArrowDown':
          e.preventDefault()
          setSelectedIndex((i) => Math.min(i + 1, filtered.length - 1))
          break
        case 'ArrowUp':
          e.preventDefault()
          setSelectedIndex((i) => Math.max(i - 1, 0))
          break
        case 'Enter':
          e.preventDefault()
          if (filtered[selectedIndex]) {
            filtered[selectedIndex].action()
            onClose()
          }
          break
        case 'Escape':
          e.preventDefault()
          onClose()
          break
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [isOpen, filtered, selectedIndex, onClose])

  if (!isOpen) return null

  return (
    <>
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/60 backdrop-blur-sm z-40 animate-fade-in"
        onClick={onClose}
      />

      {/* Palette */}
      <div className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full max-w-lg z-50 animate-fade-in">
        <div
          className="rounded-lg overflow-hidden shadow-2xl"
          style={{
            background: 'linear-gradient(135deg, rgba(13, 24, 33, 0.95) 0%, rgba(15, 31, 46, 0.95) 100%)',
            border: '1px solid rgba(16, 185, 129, 0.2)',
          }}
        >
          {/* Search input */}
          <div className="border-b border-slate-700/60 px-5 py-4 flex items-center gap-3">
            <span className="text-slate-500 text-lg">⌘</span>
            <input
              autoFocus
              type="text"
              placeholder="Search commands..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="flex-1 bg-transparent outline-none text-slate-300 placeholder-slate-600 text-sm"
            />
          </div>

          {/* Results */}
          <div className="max-h-80 overflow-y-auto">
            {filtered.length === 0 ? (
              <div className="px-5 py-12 text-center text-slate-500 text-sm">
                No commands found
              </div>
            ) : (
              <div>
                {filtered.map((cmd, idx) => (
                  <button
                    key={cmd.id}
                    onClick={() => {
                      cmd.action()
                      onClose()
                    }}
                    className={`w-full px-5 py-3 text-left text-sm transition-all duration-150 border-b border-slate-800/30 last:border-0 ${
                      idx === selectedIndex
                        ? 'bg-[#10b981]/15 text-white'
                        : 'text-slate-400 hover:text-slate-300 hover:bg-slate-900/30'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="font-medium">{cmd.label}</p>
                        <p className="text-xs text-slate-600 mt-0.5">
                          {cmd.description}
                        </p>
                      </div>
                      {cmd.shortcut && (
                        <span className="text-xs text-slate-600 ml-4 shrink-0">
                          {cmd.shortcut}
                        </span>
                      )}
                    </div>
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Footer hint */}
          <div className="border-t border-slate-700/60 px-5 py-2.5 text-xs text-slate-600 flex gap-2 justify-center">
            <span>↑↓ Navigate</span>
            <span>•</span>
            <span>Enter to select</span>
            <span>•</span>
            <span>ESC to close</span>
          </div>
        </div>
      </div>
    </>
  )
}
