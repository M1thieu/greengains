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

function _cacheKey(lat: number, lon: number, at: Date): string {
  const roundedLat = Math.round(lat * 4) / 4; // 0.25° grid
  const roundedLon = Math.round(lon * 4) / 4;
  const hourBucket = at.toISOString().slice(0, 13); // yyyy-MM-ddTHH
  return `${roundedLat},${roundedLon},${hourBucket}`;
}

type HourlyBlock = Partial<Record<(typeof HOURLY_VARS)[number], number[]>> & {
  time?: string[];
};

/** Index of the hourly sample closest to [at], or -1 when there are none. */
function _closestIndex(times: string[], at: Date): number {
  const targetMs = at.getTime();
  let bestIdx = -1;
  let bestDiff = Infinity;
  for (let i = 0; i < times.length; i++) {
    const diff = Math.abs(new Date(`${times[i]}Z`).getTime() - targetMs);
    if (diff < bestDiff) { bestDiff = diff; bestIdx = i; }
  }
  return bestIdx;
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
  if (cached && cached.expiresAt > Date.now()) return cached.value;

  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}` +
      `&hourly=${HOURLY_VARS.join(',')}&past_days=1&forecast_days=1&timezone=UTC`;
    const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) return null;

    const data = await res.json() as { hourly?: HourlyBlock };
    const times = data.hourly?.time;
    if (!times || times.length === 0) return null;

    const idx = _closestIndex(times, at);
    if (idx < 0) return null;

    const pick = (name: (typeof HOURLY_VARS)[number]): number | null => {
      const series = data.hourly?.[name];
      const v = series?.[idx];
      return typeof v === 'number' ? v : null;
    };

    const value: WeatherObservation = {
      surfacePressureHpa: pick('surface_pressure'),
      temperatureC: pick('temperature_2m'),
    };

    if (_cache.size >= MAX_CACHE_ENTRIES) _cache.clear();
    _cache.set(key, { value, expiresAt: Date.now() + CACHE_TTL_MS });
    return value;
  } catch {
    return null;
  }
}
