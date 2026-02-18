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

// Enable anonymous authentication for demo/public access
auth.settings.appVerificationDisabledForTesting = true

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
// API Fetch Wrapper
// ============================================================================

interface FetchOptions extends RequestInit {
  timeout?: number
}

/**
 * Fetch wrapper that automatically adds Firebase auth token
 */
async function apiCall<T>(
  endpoint: string,
  options: FetchOptions = {}
): Promise<T> {
  const { timeout = 10000, ...fetchOptions } = options

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

      return await response.json()
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
}

export interface SensorReading {
  timestamp: string
  value: number | null
}

export interface ExportData {
  [key: string]: unknown
}

/**
 * Get aggregated sensor data
 * Query parameters: timeRange, geohash, bucket
 */
export async function getAggregatedData(
  params?: Record<string, string | number>
): Promise<AggregatedData> {
  const queryString = params ? `?${new URLSearchParams(Object.entries(params).map(([k, v]) => [k, String(v)])).toString()}` : ''

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
  }>(`/api/v1/data/aggregated${queryString}`)

  // Transform backend response to dashboard expected format
  const items = response.items || []
  const totalReadings = items.reduce((sum, item) => sum + (item.samples_count || 0), 0)
  const maxDevices = items.reduce((max, item) => Math.max(max, item.device_count || 0), 0)
  const avgLight = items.length > 0
    ? items.reduce((sum, item) => sum + (item.avg_light || 0), 0) / items.length
    : 0
  const avgMovement = items.length > 0
    ? items.reduce((sum, item) => sum + (item.movement_score || 0), 0) / items.length
    : 0
  const avgPressure = items.length > 0
    ? items.reduce((sum, item) => sum + (item.avg_gyro_rms || 0), 0) / items.length
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
        readings: items.filter(i => i.avg_gyro_rms !== null).length,
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
  const queryString = params ? `?${new URLSearchParams(Object.entries(params).map(([k, v]) => [k, String(v)])).toString()}` : ''
  return apiCall<SensorReading[]>(`/api/v1/data/readings/${sensor}${queryString}`)
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
 * Get coverage data per geohash
 */
export async function getCoverageData(
  params?: Record<string, string | number>
): Promise<CoverageItem[]> {
  const queryString = params ? `?${new URLSearchParams(Object.entries(params).map(([k, v]) => [k, String(v)])).toString()}` : ''
  const response = await apiCall<{
    hours: number
    min_devices: number
    items: CoverageItem[]
  }>(`/api/v1/data/coverage${queryString}`)
  return response.items || []
}

/**
 * Export data as CSV
 */
export async function exportData(
  params?: Record<string, string | number>
): Promise<Blob> {
  const queryString = params ? `?${new URLSearchParams(Object.entries(params).map(([k, v]) => [k, String(v)])).toString()}` : ''
  const token = await getAuthToken()

  const response = await fetch(`${API_BASE_URL}/api/v1/data/export${queryString}`, {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  })

  if (!response.ok) {
    throw new Error(`Export failed: ${response.statusText}`)
  }

  return await response.blob()
}

/**
 * Get health status
 */
export async function getHealthStatus(): Promise<{ status: string; database: { status: string } }> {
  try {
    const response = await fetch(`${API_BASE_URL}/health`)
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
  return apiCall('/api/v1/auth/me')
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
 * Generate mock sensor readings for development/demo
 */
export function generateMockSensorReadings(sensor: string, count = 100): SensorReading[] {
  const readings: SensorReading[] = []
  const now = new Date()

  for (let i = count - 1; i >= 0; i--) {
    const time = new Date(now.getTime() - i * 60000) // 1 min intervals
    readings.push({
      timestamp: time.toISOString(),
      Light: Math.floor(Math.random() * 800) + 50,
      Movement: Math.random() * 5,
      Pressure: 100 + Math.random() * 4,
      Quality: Math.random(),
    })
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
  mockFn: () => T
): Promise<T> {
  try {
    return await apiFn()
  } catch (error) {
    console.warn('API call failed, using mock data:', error)
    return mockFn()
  }
}
