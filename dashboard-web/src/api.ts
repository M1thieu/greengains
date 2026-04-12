import { initializeApp } from 'firebase/app'
import {
  getAuth,
  signInWithPopup,
  GoogleAuthProvider,
  signInAnonymously,
  signOut,
  onAuthStateChanged,
  User,
  Auth,
} from 'firebase/auth'

// Firebase Web Config from environment variables
// Get values from Firebase Console → Project Settings → Web App Config
const FIREBASE_CONFIG = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
}

// Validate Firebase config
if (!FIREBASE_CONFIG.apiKey) {
  console.error('Firebase config not found. Please create .env file with Firebase credentials.')
}

// Backend API base URL
const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://greengains.onrender.com'

// Initialize Firebase
const app = initializeApp(FIREBASE_CONFIG)
const auth = getAuth(app)


// ============================================================================
// Auth Functions
// ============================================================================

/**
 * Sign in user with Google
 */
export async function signInUser(): Promise<User> {
  try {
    const provider = new GoogleAuthProvider()
    const result = await signInWithPopup(auth, provider)
    return result.user
  } catch (error) {
    console.error('Google sign in failed:', error)
    throw error
  }
}

/**
 * Sign in as demo user (anonymous)
 */
export async function signInAsDemo(): Promise<User> {
  try {
    const result = await signInAnonymously(auth)
    return result.user
  } catch (error) {
    console.error('Demo sign in failed:', error)
    throw error
  }
}

/**
 * Sign out user
 */
export async function signOutUser(): Promise<void> {
  try {
    await signOut(auth)
  } catch (error) {
    console.error('Sign out failed:', error)
    throw error
  }
}

/**
 * Get current user's Firebase auth token
 */
export async function getAuthToken(): Promise<string> {
  const user = auth.currentUser
  if (!user) {
    throw new Error('User not authenticated')
  }
  return await user.getIdToken()
}

/**
 * Get current user
 */
export function getCurrentUser(): User | null {
  return auth.currentUser
}

/**
 * Listen to auth state changes
 */
export function onAuthStateChange(callback: (user: User | null) => void): () => void {
  return onAuthStateChanged(auth, callback)
}

// ============================================================================
// Simple in-memory cache (stale-while-revalidate style)
// ============================================================================

interface CacheEntry { data: unknown; ts: number }
const _cache = new Map<string, CacheEntry>()

function cacheGet<T>(key: string, ttlMs: number): T | null {
  const entry = _cache.get(key)
  if (!entry) return null
  if (Date.now() - entry.ts > ttlMs) return null
  return entry.data as T
}
function cacheSet(key: string, data: unknown) {
  _cache.set(key, { data, ts: Date.now() })
}

// ============================================================================
// API Fetch Wrapper
// ============================================================================

interface FetchOptions extends RequestInit {
  timeout?: number
  cacheTtl?: number   // ms; if set, caches response by url key
}

/**
 * Fetch wrapper that automatically adds Firebase auth token
 */
async function apiCall<T>(
  endpoint: string,
  options: FetchOptions = {}
): Promise<T> {
  const { timeout = 10000, cacheTtl, ...fetchOptions } = options

  // Return cached response if still fresh
  const cacheKey = endpoint
  if (cacheTtl) {
    const cached = cacheGet<T>(cacheKey, cacheTtl)
    if (cached !== null) return cached
  }

  try {
    // Get auth token
    const token = await getAuthToken()

    // Prepare headers
    const headers = {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      ...fetchOptions.headers,
    }

    // Build full URL
    const url = `${API_BASE_URL}${endpoint}`

    // Create AbortController for timeout
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), timeout)

    try {
      // Make request
      const response = await fetch(url, {
        ...fetchOptions,
        headers,
        signal: controller.signal,
      })

      clearTimeout(timeoutId)

      // Handle response
      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}))
        throw new Error(
          errorData.error || `HTTP ${response.status}: ${response.statusText}`
        )
      }

      const data = await response.json()
      if (cacheTtl) cacheSet(cacheKey, data)
      return data
    } finally {
      clearTimeout(timeoutId)
    }
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw new Error(`Request timeout (${timeout}ms)`)
    }
    throw error
  }
}

// ============================================================================
// API Endpoints
// ============================================================================

// ─── Endpoint constants ───────────────────────────────────────────────────────
const ENDPOINTS = {
  DATA_AGGREGATED: '/api/v1/data/aggregated',
  DATA_READINGS:   '/api/v1/data/readings',
  DATA_COVERAGE:   '/api/v1/data/coverage',
  DATA_EXPORT:     '/api/v1/data/export',
  AUTH_ME:         '/api/v1/auth/me',
  HEALTH:          '/health',
} as const

// ─── Query string helper ──────────────────────────────────────────────────────
function buildQueryString(params?: Record<string, string | number>): string {
  if (!params) return ''
  return `?${new URLSearchParams(Object.entries(params).map(([k, v]) => [k, String(v)])).toString()}`
}

export interface AggregatedData {
  summary: {
    totalReadings: number
    activeSensors: number
    averageQuality: number
  }
  sensors: Array<{
    name: string
    type: 'Light' | 'Movement' | 'Pressure' | 'Quality'
    readings: number
    avgValue: number
  }>
  /** ISO timestamp of the most recent sensor batch in the returned window. Null if no data. */
  latestDataAt: string | null
}

export interface SensorReading {
  timestamp: string
  value: number | null
}

/**
 * Get aggregated sensor data
 * Query parameters: timeRange, geohash, bucket
 */
export async function getAggregatedData(
  params?: Record<string, string | number>
): Promise<AggregatedData> {
  // Backend returns raw aggregated items, we transform to dashboard format
  const response = await apiCall<{
    tier: string
    data_retention_days: number
    items: Array<{
      timestamp: string
      geohash: string
      samples_count: number
      device_count: number
      avg_light: number | null
      avg_light_min: number | null
      avg_light_max: number | null
      avg_accel_rms: number | null
      avg_gyro_rms: number | null
      movement_score: number | null
      battery_avg: number | null
      location_share: number | null
      device_hours: number | null
      quality_samples: number | null
      quality_valid_ratio: number | null
      quality_pocket_ratio: number | null
      [key: string]: unknown
    }>
    next_cursor: string | null
    has_more: boolean
  }>(`${ENDPOINTS.DATA_AGGREGATED}${buildQueryString(params)}`)

  // Transform backend response to dashboard expected format
  const items = response.items || []
  const latestDataAt = items.length > 0
    ? items.reduce((latest, item) => (item.timestamp > latest ? item.timestamp : latest), '')
    : null
  const totalReadings = items.reduce((sum, item) => sum + (item.samples_count || 0), 0)
  const maxDevices = items.reduce((max, item) => Math.max(max, item.device_count || 0), 0)
  const avgLight = items.length > 0
    ? items.reduce((sum, item) => sum + (item.avg_light || 0), 0) / items.length
    : 0
  const avgMovement = items.length > 0
    ? items.reduce((sum, item) => sum + (item.movement_score || 0), 0) / items.length
    : 0
  const pressureItems = items.filter(i => i.avg_pressure != null)
  const avgPressure = pressureItems.length > 0
    ? pressureItems.reduce((sum, item) => sum + (item.avg_pressure as number), 0) / pressureItems.length
    : 0
  const avgQuality = items.length > 0
    ? items.reduce((sum, item) => sum + (item.quality_valid_ratio || 0), 0) / items.length
    : 0

  return {
    summary: {
      totalReadings,
      activeSensors: maxDevices,  // max devices in any window
      averageQuality: avgQuality,  // real quality ratio from DB
    },
    latestDataAt,
    sensors: [
      {
        name: 'Light',
        type: 'Light',
        readings: items.filter(i => i.avg_light !== null).length,
        avgValue: avgLight,
      },
      {
        name: 'Movement',
        type: 'Movement',
        readings: items.filter(i => i.movement_score !== null).length,
        avgValue: avgMovement,
      },
      {
        name: 'Pressure',
        type: 'Pressure',
        readings: pressureItems.length,
        avgValue: avgPressure,
      },
      {
        name: 'Quality',
        type: 'Quality',
        readings: items.filter(i => i.quality_valid_ratio !== null).length,
        avgValue: avgQuality,
      },
    ],
  }
}

/**
 * Get sensor readings with filtering
 */
export async function getSensorReadings(
  sensor: string,
  params?: Record<string, string | number>
): Promise<SensorReading[]> {
  return apiCall<SensorReading[]>(`${ENDPOINTS.DATA_READINGS}/${sensor}${buildQueryString(params)}`)
}

export interface CoverageItem {
  geohash: string
  samples_count: number
  device_hours: number
  avg_light: number | null
  quality_valid_ratio: number | null
  last_seen: string
}

/**
 * Get raw aggregated items (for DataTable — no transformation)
 */
export async function getAggregatedItems(
  params?: Record<string, string | number>
): Promise<Array<{
  timestamp: string
  geohash: string
  samples_count: number
  device_count: number
  avg_light: number | null
  movement_score: number | null
  quality_valid_ratio: number | null
  [key: string]: unknown
}>> {
  const response = await apiCall<{ items: any[] }>(`${ENDPOINTS.DATA_AGGREGATED}${buildQueryString(params)}`)
  return response.items || []
}

/**
 * Get coverage data per geohash
 */
export async function getCoverageData(
  params?: Record<string, string | number>
): Promise<CoverageItem[]> {
  const response = await apiCall<{
    hours: number
    min_devices: number
    items: CoverageItem[]
  }>(`${ENDPOINTS.DATA_COVERAGE}${buildQueryString(params)}`, { cacheTtl: 5 * 60_000 })
  return response.items || []
}

/**
 * Export data as CSV (POST — backend expects JSON body)
 */
export async function exportData(params?: {
  from?: string
  to?: string
  geohash?: string
  format?: 'csv' | 'json'
}): Promise<Blob> {
  const token = await getAuthToken()

  const response = await fetch(`${API_BASE_URL}${ENDPOINTS.DATA_EXPORT}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ format: 'csv', ...params }),
  })

  if (!response.ok) {
    const err = await response.json().catch(() => ({}))
    throw new Error(err.message || err.error || `Export failed: ${response.statusText}`)
  }

  return await response.blob()
}

/**
 * Get health status
 */
export async function getHealthStatus(): Promise<{ status: string; database: { status: string } }> {
  try {
    const response = await fetch(`${API_BASE_URL}${ENDPOINTS.HEALTH}`)
    return await response.json()
  } catch (error) {
    console.error('Health check failed:', error)
    throw error
  }
}

/**
 * Get current user info
 */
export async function getCurrentUserInfo() {
  return apiCall(ENDPOINTS.AUTH_ME)
}

// ============================================================================
// Mock Data (for when backend is not available)
// ============================================================================

/**
 * Generate mock aggregated data for development/demo
 */
export function generateMockAggregatedData(): AggregatedData {
  return {
    summary: {
      totalReadings: 12453,
      activeSensors: 8,
      averageQuality: 0.87,
    },
    sensors: [
      {
        name: 'Light',
        type: 'Light',
        readings: 3200,
        avgValue: 450,
      },
      {
        name: 'Movement',
        type: 'Movement',
        readings: 2800,
        avgValue: 2.3,
      },
      {
        name: 'Pressure',
        type: 'Pressure',
        readings: 3100,
        avgValue: 101.2,
      },
      {
        name: 'Quality',
        type: 'Quality',
        readings: 3353,
        avgValue: 0.87,
      },
    ],
  }
}

/**
 * Generate mock sensor readings spanning the actual time range.
 * Interval scales with range so charts always look correct:
 *   24h → 5-min buckets (~288 pts), 7d → 1-hour (~168), 30d/90d → 6-hour / 1-day
 */
export function generateMockSensorReadings(sensor: string, timeRange = '24h'): SensorReading[] {
  const RANGE_DAYS: Record<string, number> = { '24h': 1, '7d': 7, '30d': 30, '90d': 90 }
  const days = RANGE_DAYS[timeRange] ?? 1
  const totalMs = days * 86_400_000

  // Pick interval so we get a reasonable number of data points
  const intervalMs =
    days <= 1  ? 5 * 60_000          // 5 min → ~288 pts
    : days <= 7  ? 60 * 60_000        // 1 hour → ~168 pts
    : days <= 30 ? 6 * 60 * 60_000   // 6 hours → ~120 pts
    : 24 * 60 * 60_000               // 1 day → 90 pts

  const now = new Date()
  const start = new Date(now.getTime() - totalMs)
  const count = Math.ceil(totalMs / intervalMs)

  const readings: SensorReading[] = []
  for (let i = 0; i < count; i++) {
    const time = new Date(start.getTime() + i * intervalMs)
    let value: number
    switch (sensor) {
      case 'Light':    value = Math.floor(Math.random() * 800) + 50; break
      case 'Movement': value = Math.random() * 5; break
      case 'Pressure': value = 100 + Math.random() * 4; break
      case 'Quality':  value = 0.6 + Math.random() * 0.4; break
      default:         value = Math.random() * 100
    }
    readings.push({ timestamp: time.toISOString(), value })
  }

  return readings
}

// ============================================================================
// Safe API Call Wrapper (with fallback to mock)
// ============================================================================

/**
 * Safely call API with fallback to mock data
 */
export async function safeApiCall<T>(
  apiFn: () => Promise<T>,
  mockFn: () => T,
  onFallback?: () => void,
): Promise<T> {
  try {
    return await apiFn()
  } catch (error) {
    console.warn('API call failed, using mock data:', error)
    onFallback?.()
    return mockFn()
  }
}
