import { cellToLatLng } from 'h3-js';

interface GeoName {
  road?: string;
  neighbourhood?: string;
  suburb?: string;
  city_district?: string;
  town?: string;
  city?: string;
  county?: string;
}

interface NominatimResponse {
  address?: GeoName;
  display_name?: string;
}

// In-memory cache — H3 cells are static geography, cache indefinitely per process
const _cache = new Map<string, string>();

// Nominatim requires ≤1 req/s. Simple queue with 1100ms spacing.
let _lastCall = 0;
async function _throttledFetch(url: string): Promise<Response> {
  const now = Date.now();
  const wait = Math.max(0, 1100 - (now - _lastCall));
  if (wait > 0) await new Promise(r => setTimeout(r, wait));
  _lastCall = Date.now();
  return fetch(url, {
    headers: { 'User-Agent': 'GreenGains/1.0 (contact@eremat.org)' },
    signal: AbortSignal.timeout(5000),
  });
}

/** Best human-readable name for an address object, shortest meaningful label first. */
function _bestName(addr: GeoName): string | null {
  return addr.road
    ?? addr.neighbourhood
    ?? addr.suburb
    ?? addr.city_district
    ?? addr.town
    ?? addr.city
    ?? addr.county
    ?? null;
}

/**
 * Resolve an H3 cell index to a human-readable street/area name.
 * Returns null on failure — callers must handle gracefully.
 */
export async function cellToStreetName(h3Index: string): Promise<string | null> {
  if (_cache.has(h3Index)) return _cache.get(h3Index)!;

  try {
    const [lat, lng] = cellToLatLng(h3Index);
    const url = `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lng}&format=json&zoom=16&addressdetails=1`;
    const res = await _throttledFetch(url);
    if (!res.ok) return null;

    const data = await res.json() as NominatimResponse;
    const name = data.address ? _bestName(data.address) : null;

    if (name) _cache.set(h3Index, name);
    return name;
  } catch {
    return null;
  }
}

/**
 * Resolve multiple cells in sequence (respects Nominatim rate limit).
 * Returns a map of h3Index → name. Missing entries = resolution failed.
 */
export async function resolveCellNames(cells: string[]): Promise<Map<string, string>> {
  const result = new Map<string, string>();
  for (const cell of cells) {
    const name = await cellToStreetName(cell);
    if (name) result.set(cell, name);
  }
  return result;
}
