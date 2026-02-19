export function KPISkeleton() {
  return (
    <div className="grid grid-cols-4 gap-5">
      {Array.from({ length: 4 }).map((_, i) => (
        <div
          key={i}
          className="rounded-lg p-5 bg-gradient-to-br from-slate-800/50 to-slate-800/25 overflow-hidden"
          style={{ animation: `shimmer 2s infinite`, animationDelay: `${i * 100}ms` }}
        >
          <div className="h-3 w-24 bg-slate-700/50 rounded-full mb-3" />
          <div className="h-6 w-16 bg-slate-700/50 rounded-full mb-2" />
          <div className="h-2.5 w-32 bg-slate-700/30 rounded-full" />
        </div>
      ))}
    </div>
  )
}

export function ChartSkeleton() {
  return (
    <div className="col-span-2 rounded-lg overflow-hidden p-6 bg-gradient-to-br from-slate-800/50 to-slate-800/25">
      <div className="h-4 w-32 bg-slate-700/50 rounded-full mb-6" />
      <div className="space-y-2 mb-6">
        {Array.from({ length: 4 }).map((_, i) => (
          <div
            key={i}
            className="h-2.5 bg-slate-700/30 rounded-full"
            style={{
              animation: `shimmer 2s infinite`,
              animationDelay: `${i * 100}ms`,
              width: `${80 + Math.random() * 20}%`,
            }}
          />
        ))}
      </div>
      <div className="h-48 bg-slate-700/20 rounded-lg" style={{ animation: 'shimmer 2s infinite' }} />
    </div>
  )
}

export function CoverageSkeleton() {
  return (
    <div className="rounded-lg overflow-hidden p-6 bg-gradient-to-br from-slate-800/50 to-slate-800/25">
      <div className="h-4 w-32 bg-slate-700/50 rounded-full mb-4" />
      <div className="space-y-3">
        {Array.from({ length: 3 }).map((_, i) => (
          <div key={i} className="space-y-2">
            <div
              className="h-3 w-20 bg-slate-700/50 rounded-full"
              style={{ animation: 'shimmer 2s infinite', animationDelay: `${i * 100}ms` }}
            />
            <div
              className="h-2 bg-slate-700/30 rounded-full"
              style={{
                animation: 'shimmer 2s infinite',
                animationDelay: `${i * 100 + 50}ms`,
              }}
            />
          </div>
        ))}
      </div>
    </div>
  )
}
