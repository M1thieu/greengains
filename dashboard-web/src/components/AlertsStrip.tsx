import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import type { Alert } from '../hooks/useDashboardData'

interface Props {
  alerts: Alert[]
}

/** Severity-aware alert list. Errors are non-dismissible; warnings are. Owns its own dismissed state. */
export default function AlertsStrip({ alerts }: Props) {
  const { t } = useTranslation()
  const [dismissed, setDismissed] = useState<number[]>([])
  const visible = alerts.filter((_, i) => !dismissed.includes(i))

  // Auto-reset dismissed list when alerts change (new fetch cycle)
  // so critical alerts can't be permanently suppressed across refreshes.
  const dismiss = (i: number) => setDismissed((prev) => [...prev, i])

  if (!visible.length) return null

  return (
    <div className="rounded-lg overflow-hidden card-elevated divide-y divide-slate-800/50">
      {alerts.map((a, i) => !dismissed.includes(i) && (
        <div
          key={i}
          className={`flex items-center gap-3 px-5 py-3 group ${a.level === 'error' ? 'bg-red-950/30' : ''}`}
        >
          {/* Severity icon */}
          {a.level === 'error' ? (
            <svg className="flex-shrink-0 w-4 h-4 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
            </svg>
          ) : (
            <svg className="flex-shrink-0 w-4 h-4 text-yellow-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" />
            </svg>
          )}

          {/* Severity label */}
          <span className={`flex-shrink-0 text-[10px] font-bold uppercase tracking-wider ${
            a.level === 'error' ? 'text-red-400' : 'text-yellow-400'
          }`}>
            {a.level === 'error' ? t('alerts.critical') : t('alerts.warning')}
          </span>

          {/* Message */}
          <p className="flex-1 text-[11px] text-slate-300 font-medium">{a.msg}</p>

          {/* Timestamp */}
          <span className="flex-shrink-0 text-[10px] text-slate-600">{a.time}</span>

          {/* Dismiss — critical alerts cannot be dismissed */}
          {a.level !== 'error' && (
            <button
              onClick={() => dismiss(i)}
              className="flex-shrink-0 text-slate-600 hover:text-slate-400 opacity-0 group-hover:opacity-100 transition-opacity p-1 -mr-1"
              title={t('alerts.dismiss')}
              aria-label={t('alerts.dismiss')}
            >
              <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          )}
        </div>
      ))}
    </div>
  )
}
