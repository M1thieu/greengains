/**
 * Shared geohash decoder — no extra dependency.
 * Used by user.ts (global tile fallback) and h3-backfill.ts.
 * Once all rows have h3_index populated this becomes a thin fallback only.
 */
const GH_BASE32 = '0123456789bcdefghjkmnpqrstuvwxyz';

export function decodeGeohash(hash: string): { lat: number; lon: number } | null {
  if (!hash || hash.length === 0) return null;
  let isLon = true;
  const lat = [-90.0, 90.0];
  const lon = [-180.0, 180.0];
  for (const ch of hash) {
    const idx = GH_BASE32.indexOf(ch);
    if (idx === -1) return null;
    for (let bit = 4; bit >= 0; bit--) {
      const bitN = (idx >> bit) & 1;
      if (isLon) {
        const mid = (lon[0] + lon[1]) / 2;
        if (bitN) lon[0] = mid; else lon[1] = mid;
      } else {
        const mid = (lat[0] + lat[1]) / 2;
        if (bitN) lat[0] = mid; else lat[1] = mid;
      }
      isLon = !isLon;
    }
  }
  return { lat: (lat[0] + lat[1]) / 2, lon: (lon[0] + lon[1]) / 2 };
}
