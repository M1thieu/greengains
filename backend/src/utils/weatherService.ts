interface CacheEntry {
  value: number;
  expiresAt: number;
}

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

interface OpenMeteoHourly {
  hourly?: {
    time: string[];
    surface_pressure: number[];
  };
}

/**
 * Regional surface pressure (hPa) from Open-Meteo for the given location/time —
 * the "background field" against which a local aggregate can be compared to
 * isolate a local anomaly (Optimal-Interpolation-style: local reading minus
 * background). surface_pressure (not sea-level) is used because it already
 * accounts for the location's real elevation, matching what a phone barometer
 * reads on the ground there — no altitude correction needed.
 *
 * Returns null on any failure (network, parse, missing data). Callers must
 * skip normalization gracefully rather than treat this as fatal.
 */
export async function getSurfacePressureHpa(lat: number, lon: number, at: Date): Promise<number | null> {
  const key = _cacheKey(lat, lon, at);
  const cached = _cache.get(key);
  if (cached && cached.expiresAt > Date.now()) return cached.value;

  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}` +
      `&hourly=surface_pressure&past_days=1&forecast_days=1&timezone=UTC`;
    const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) return null;

    const data = await res.json() as OpenMeteoHourly;
    const times = data.hourly?.time;
    const pressures = data.hourly?.surface_pressure;
    if (!times || !pressures || times.length === 0) return null;

    // Closest hourly sample to the target time.
    const targetMs = at.getTime();
    let bestIdx = 0;
    let bestDiff = Infinity;
    for (let i = 0; i < times.length; i++) {
      const diff = Math.abs(new Date(`${times[i]}Z`).getTime() - targetMs);
      if (diff < bestDiff) { bestDiff = diff; bestIdx = i; }
    }
    const value = pressures[bestIdx];
    if (typeof value !== 'number') return null;

    if (_cache.size >= MAX_CACHE_ENTRIES) _cache.clear();
    _cache.set(key, { value, expiresAt: Date.now() + CACHE_TTL_MS });
    return value;
  } catch {
    return null;
  }
}
