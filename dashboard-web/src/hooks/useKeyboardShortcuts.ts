import { useEffect } from 'react'

interface ShortcutHandler {
  (e: KeyboardEvent): void
}

export function useKeyboardShortcuts(shortcuts: Record<string, ShortcutHandler>) {
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Ignore if typing in input
      if ((e.target as HTMLElement).tagName === 'INPUT') {
        if (e.key === 'Escape') {
          (e.target as HTMLInputElement).blur()
        }
        return
      }

      // Check for Cmd+K (Mac) or Ctrl+K (Windows/Linux)
      const isMeta = e.metaKey || e.ctrlKey
      const key = `${isMeta ? 'cmd+' : ''}${e.key.toLowerCase()}`

      if (shortcuts[key]) {
        e.preventDefault()
        shortcuts[key](e)
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [shortcuts])
}
