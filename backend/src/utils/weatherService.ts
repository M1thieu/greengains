/** A regional weather observation used as a background field for local readings. */
export interface WeatherObservation {
  /** Surface (station-level) pressure in hPa — comparable to a phone barometer. */
  surfacePressureHpa: number | null;
  /** Air temperature at 2m in °C. */
  temperatureC: number | null;
}

interface CacheEntry {
  value: WeatherObservation;
  expiresAt: number;
}

/**
 * Hourly variables requested from Open-Meteo. One request covers all of them at
 * no extra cost, so adding a variable here plus a field on [WeatherObservation]
 * is the whole change — no second fetch, no second cache.
 */
const HOURLY_VARS = ['surface_pressure', 'temperature_2m'] as const;

// In-memory cache — weather is regional and changes slowly, so many nearby H3
// cells within the same hour share one lookup. Bucketed by a coarse lat/lon
// grid (~25km) + hour, matching Open-Meteo's hourly granularity.
const _cache = new Map<string, CacheEntry>();
const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour
const MAX_CACHE_ENTRIES = 500; // self-limiting; buckets rotate hourly anyway

// Lookups return null on any failure by design, so without counters a broken or rate-limited
// weather API is invisible: pressure_anomaly_hpa would just silently stay empty.
const _stats = { ok: 0, failed: 0, cacheHits: 0, lastSuccessAt: null as string | null, lastFailureAt: null as string | null };

/** Cumulative since process start. Exposed on /health. */
export function getWeatherStats() {
  return { ..._stats };
}

function _fail(): null {
  _stats.failed++;
  _stats.lastFailureAt = new Date().toISOString();
  return null;
}

function _cacheKey(lat: number, lon: number, at: Date): string {
  const roundedLat = Math.round(lat * 4) / 4; // 0.25° grid
  const roundedLon = Math.round(lon * 4) / 4;
  const hourBucket = at.toISOString().slice(0, 13); // yyyy-MM-ddTHH
  return `${roundedLat},${roundedLon},${hourBucket}`;
}

type HourlyBlock = Partial<Record<(typeof HOURLY_VARS)[number], number[]>> & {
  time?: string[];
};

/**
 * Linear-interpolation weights for [at] between two bracketing hourly samples: the index just
 * at-or-before it and the fraction of the hour elapsed since. Surface pressure and temperature
 * both move smoothly on an hourly timescale outside of sharp frontal passages, so the true value
 * between two samples is close to their straight-line interpolation — closer than either sample
 * alone, which is what picking the single nearest hour amounts to.
 *
 * Returns null when [at] falls outside the fetched series (before the first sample or after the
 * last): extrapolating past the data would silently invent a value instead of reporting the gap.
 */
export function _interpolationWeights(times: string[], at: Date): { i: number; frac: number } | null {
  const targetMs = at.getTime();
  const ts = times.map(t => new Date(`${t}Z`).getTime());
  if (ts.length === 0 || targetMs < ts[0] || targetMs > ts[ts.length - 1]) return null;
  let i = 0;
  while (i + 1 < ts.length && ts[i + 1] <= targetMs) i++;
  if (i + 1 >= ts.length) return { i, frac: 0 }; // exact last sample
  const span = ts[i + 1] - ts[i];
  return { i, frac: span > 0 ? (targetMs - ts[i]) / span : 0 };
}

/** Value of an hourly series at [w], linearly interpolated; null if either bracketing sample is missing. */
export function _interpolate(series: (number | undefined)[] | undefined, w: { i: number; frac: number }): number | null {
  const a = series?.[w.i];
  if (typeof a !== 'number') return null;
  if (w.frac === 0) return a;
  const b = series?.[w.i + 1];
  return typeof b === 'number' ? a + (b - a) * w.frac : null;
}

/**
 * Regional weather at a location/time — the "background field" against which a
 * local aggregate can be compared to isolate a local anomaly
 * (Optimal-Interpolation-style: local reading minus background).
 *
 * surface_pressure (not sea-level) is used because it already accounts for the
 * location's real elevation, matching what a phone barometer reads on the
 * ground there — no altitude correction needed.
 *
 * Returns null on any failure (network, parse, missing data). Individual fields
 * may also be null when that variable is missing. Callers must degrade
 * gracefully rather than treat either case as fatal.
 */
export async function getWeatherAt(lat: number, lon: number, at: Date): Promise<WeatherObservation | null> {
  const key = _cacheKey(lat, lon, at);
  const cached = _cache.get(key);
  if (cached && cached.expiresAt > Date.now()) {
    _stats.cacheHits++;
    return cached.value;
  }

  try {
    // `past_days`/`forecast_days` are counted back/forward from TODAY, not from [at] — a fixed
    // past_days=1 only ever covers "yesterday to tomorrow". The aggregator can fall behind (a
    // stalled job, a redeploy) and then processes a backlog of older windows; before this, any
    // [at] older than ~1 day fell outside the fetched series, and the old nearest-sample lookup
    // still returned whatever it had — silently comparing a batch to the wrong day's weather
    // instead of failing. Requesting enough past_days to cover [at] turns that into a real fetch
    // that succeeds, and _interpolationWeights below still refuses to extrapolate past whatever
    // the request did cover.
    // 92 is the Open-Meteo forecast API's documented maximum for past_days, and SENSOR_BATCH_RETENTION_DAYS
    // (90) is how old a raw batch needing this lookup can ever be, so every in-retention batch fits.
    const daysAgo = Math.max(0, Math.ceil((Date.now() - at.getTime()) / 86_400_000));
    const daysAhead = Math.max(0, Math.ceil((at.getTime() - Date.now()) / 86_400_000));
    const pastDays = Math.min(92, daysAgo + 1); // +1: rounding up whole days can still land a UTC hour short
    const forecastDays = Math.min(16, Math.max(1, daysAhead + 1));

    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}` +
      `&hourly=${HOURLY_VARS.join(',')}&past_days=${pastDays}&forecast_days=${forecastDays}&timezone=UTC`;
    const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) return _fail();

    const data = await res.json() as { hourly?: HourlyBlock };
    const times = data.hourly?.time;
    if (!times || times.length === 0) return _fail();

    const w = _interpolationWeights(times, at);
    if (!w) return _fail(); // [at] fell outside the fetched series — do not extrapolate

    const value: WeatherObservation = {
      surfacePressureHpa: _interpolate(data.hourly?.surface_pressure, w),
      temperatureC: _interpolate(data.hourly?.temperature_2m, w),
    };

    if (_cache.size >= MAX_CACHE_ENTRIES) _cache.clear();
    _cache.set(key, { value, expiresAt: Date.now() + CACHE_TTL_MS });
    _stats.ok++;
    _stats.lastSuccessAt = new Date().toISOString();
    return value;
  } catch {
    return _fail();
  }
}
