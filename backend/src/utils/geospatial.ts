/**
 * Geospatial Utilities
 *
 * H3 hexagonal hierarchical geospatial indexing system.
 * Provides better tiling than traditional geohash for heatmaps and coverage analysis.
 *
 * Resolution levels (for reference):
 * - 6: ~36 km² per hex (city-level coverage)
 * - 7: ~5 km² per hex (neighborhood-level)
 * - 8: ~0.7 km² per hex (block-level)
 * - 9: ~0.1 km² per hex (building-level)
 */

import { latLngToCell, cellToBoundary, getResolution, cellToParent, cellToChildren } from 'h3-js';

/**
 * Default H3 resolution for sensor data aggregation
 * Resolution 7 = ~5km² hexagons (good for neighborhood-level insights)
 */
export const DEFAULT_H3_RESOLUTION = 7;

/**
 * Convert lat/lon coordinates to H3 cell index
 *
 * @param lat Latitude (-90 to 90)
 * @param lon Longitude (-180 to 180)
 * @param resolution H3 resolution (0-15, default 7)
 * @returns H3 cell index (hex string)
 */
export function locationToH3(lat: number, lon: number, resolution: number = DEFAULT_H3_RESOLUTION): string {
  return latLngToCell(lat, lon, resolution);
}

/**
 * Get boundary coordinates for an H3 cell (for map rendering)
 *
 * @param h3Index H3 cell index
 * @returns Array of [lat, lon] coordinates forming the hexagon boundary
 */
export function h3ToBoundary(h3Index: string): Array<[number, number]> {
  return cellToBoundary(h3Index);
}

/**
 * Get the resolution level of an H3 index
 *
 * @param h3Index H3 cell index
 * @returns Resolution level (0-15)
 */
export function getH3Resolution(h3Index: string): number {
  return getResolution(h3Index);
}

/**
 * Get parent cell at lower resolution (larger area)
 *
 * @param h3Index H3 cell index
 * @param parentResolution Target parent resolution (must be < current resolution)
 * @returns Parent H3 cell index
 */
export function getParentCell(h3Index: string, parentResolution: number): string {
  return cellToParent(h3Index, parentResolution);
}

/**
 * Get child cells at higher resolution (smaller areas)
 *
 * @param h3Index H3 cell index
 * @param childResolution Target child resolution (must be > current resolution)
 * @returns Array of child H3 cell indices
 */
export function getChildCells(h3Index: string, childResolution: number): string[] {
  return cellToChildren(h3Index, childResolution);
}

/**
 * Validate if a string is a valid H3 index
 *
 * @param h3Index Potential H3 cell index
 * @returns True if valid H3 index
 */
export function isValidH3(h3Index: string): boolean {
  try {
    getResolution(h3Index);
    return true;
  } catch {
    return false;
  }
}

/**
 * Convert legacy geohash to H3 (for migration purposes)
 * Note: This is approximate - geohash and H3 don't map 1:1
 *
 * @param geohash Geohash string (precision 4-7)
 * @param resolution Target H3 resolution
 * @returns H3 cell index or null if geohash is invalid
 */
export function geohashToH3(geohash: string, resolution: number = DEFAULT_H3_RESOLUTION): string | null {
  // Geohash decode logic would go here
  // For now, return null (migration will handle this via lat/lon)
  return null;
}
