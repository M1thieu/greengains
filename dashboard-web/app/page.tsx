export default function DashboardPage() {
  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="sticky top-0 z-50 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="container flex h-16 items-center gap-4 px-8">
          <div className="flex items-center gap-4">
            <div className="flex h-11 w-11 items-center justify-center rounded-lg bg-primary text-sm font-bold text-primary-foreground">
              GG
            </div>
            <div>
              <h1 className="text-xl font-bold">GreenGains Analytics</h1>
              <p className="text-xs text-muted-foreground uppercase tracking-wide">Smart Cities Data Platform</p>
            </div>
          </div>
          <div className="ml-auto flex items-center gap-3">
            <div className="flex items-center gap-2 rounded-md bg-muted/50 px-3 py-2">
              <div className="h-2 w-2 rounded-full bg-primary animate-pulse" />
              <span className="text-sm font-medium">Live</span>
            </div>
            <button className="inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 bg-primary text-primary-foreground hover:bg-primary/90 h-10 px-4 py-2">
              <svg className="h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8"/>
                <path d="M21 3v5h-5"/>
              </svg>
              Refresh Data
            </button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto p-8">
        <div className="grid gap-8 lg:grid-cols-[300px_1fr]">
          {/* Filters Sidebar */}
          <aside className="space-y-6">
            <div className="rounded-lg border bg-card p-6 shadow-sm">
              <h2 className="mb-6 flex items-center gap-3 text-lg font-semibold">
                <div className="flex h-8 w-8 items-center justify-center rounded-md bg-primary/10 text-xs font-bold text-primary">
                  F
                </div>
                Filters
              </h2>

              <div className="space-y-6">
                {/* Time Bucket */}
                <div className="space-y-2">
                  <label className="text-sm font-medium text-muted-foreground">Time Bucket</label>
                  <div className="flex gap-2">
                    <button className="flex-1 rounded-md border-2 border-primary bg-primary/20 px-3 py-2 text-sm font-medium text-primary transition">
                      5 Minutes
                    </button>
                    <button className="flex-1 rounded-md border bg-muted px-3 py-2 text-sm font-medium transition hover:bg-muted/70">
                      Day
                    </button>
                  </div>
                </div>

                {/* Quick Presets */}
                <div className="space-y-2">
                  <label className="text-sm font-medium text-muted-foreground">Quick Presets</label>
                  <div className="grid grid-cols-2 gap-2">
                    {['24h', '7d', '30d', '90d'].map((preset) => (
                      <button
                        key={preset}
                        className="rounded-md border bg-muted px-3 py-2 text-sm font-medium transition hover:border-primary hover:bg-muted/70 hover:text-primary"
                      >
                        {preset}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Filters Actions */}
                <div className="flex flex-col gap-2 pt-4">
                  <button className="w-full rounded-md bg-primary px-4 py-3 text-sm font-medium text-primary-foreground transition hover:bg-primary/90">
                    Apply Filters
                  </button>
                  <button className="w-full rounded-md border bg-muted px-4 py-2 text-sm font-medium transition hover:bg-muted/70">
                    Clear
                  </button>
                </div>
              </div>
            </div>
          </aside>

          {/* Dashboard Content */}
          <div className="space-y-8">
            {/* Summary Cards */}
            <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
              {[
                { label: 'Total Samples', value: '5.5K', subtitle: 'Across 24 windows', gradient: 'from-primary to-emerald-600' },
                { label: 'Avg Light Level', value: '84', subtitle: 'Lux units', gradient: 'from-blue-500 to-cyan-500' },
                { label: 'Avg Devices', value: '3.2', subtitle: 'Per window', gradient: 'from-purple-500 to-pink-500' },
                { label: 'Quality Score', value: '95%', subtitle: 'Valid ratio', gradient: 'from-orange-500 to-yellow-500' },
              ].map((stat, i) => (
                <div
                  key={i}
                  className="group relative overflow-hidden rounded-lg border bg-card p-6 shadow-sm transition-all hover:shadow-md"
                >
                  <div className={`absolute inset-x-0 top-0 h-0.5 bg-gradient-to-r ${stat.gradient} opacity-0 transition-opacity group-hover:opacity-100`} />
                  <div className="text-sm font-medium text-muted-foreground">{stat.label}</div>
                  <div className="mt-3 text-3xl font-bold tracking-tight">{stat.value}</div>
                  <p className="mt-2 flex items-center gap-1 text-sm text-muted-foreground">
                    {stat.subtitle}
                  </p>
                </div>
              ))}
            </div>

            {/* Latest Aggregates Table */}
            <section className="rounded-lg border bg-card shadow-sm">
              <div className="flex items-center justify-between border-b p-6 pb-4">
                <h2 className="flex items-center gap-3 text-lg font-semibold">
                  <div className="flex h-8 w-8 items-center justify-center rounded-md bg-primary/10 text-xs font-bold text-primary">
                    A
                  </div>
                  Latest Aggregates
                  <span className="rounded-md border bg-muted/40 px-2 py-0.5 text-xs font-medium text-muted-foreground">
                    24 records
                  </span>
                </h2>
                <div className="flex items-center gap-2">
                  <button className="inline-flex items-center justify-center rounded-md border px-3 py-2 text-xs font-medium transition hover:bg-muted/30">
                    Download CSV
                  </button>
                  <button className="inline-flex items-center justify-center rounded-md border px-3 py-2 text-xs font-medium transition hover:bg-muted/30">
                    Download JSON
                  </button>
                </div>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead className="border-b bg-background">
                    <tr>
                      {['Time Window', 'Geohash', 'Samples', 'Devices', 'Avg Light', 'Movement', 'Quality'].map((header) => (
                        <th key={header} className="px-4 py-4 text-left text-xs font-semibold uppercase tracking-wide text-muted-foreground">
                          {header}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {[1, 2, 3].map((row) => (
                      <tr key={row} className="border-b transition hover:bg-muted/20">
                        <td className="px-4 py-4 text-sm font-medium">Jan 24, 08:30 AM</td>
                        <td className="px-4 py-4">
                          <code className="rounded bg-muted px-2 py-1 text-xs">u0t1x0</code>
                        </td>
                        <td className="px-4 py-4 text-sm">29</td>
                        <td className="px-4 py-4 text-sm">1</td>
                        <td className="px-4 py-4 text-sm">10</td>
                        <td className="px-4 py-4 text-sm">1.00</td>
                        <td className="px-4 py-4">
                          <span className="inline-flex rounded-md border border-primary/20 bg-primary/10 px-2 py-1 text-xs font-semibold uppercase tracking-wide text-primary">
                            100%
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>

            {/* Placeholder for Barometer Data */}
            <section className="rounded-lg border border-dashed bg-card/50 p-12 text-center shadow-sm">
              <div className="mx-auto max-w-md space-y-4">
                <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-primary/10">
                  <svg className="h-8 w-8 text-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                  </svg>
                </div>
                <h3 className="text-lg font-semibold">Barometer Data Coming Soon</h3>
                <p className="text-sm text-muted-foreground">
                  New affordable barometer sensors will add atmospheric pressure tracking to your environmental monitoring.
                </p>
              </div>
            </section>
          </div>
        </div>
      </main>
    </div>
  )
}
