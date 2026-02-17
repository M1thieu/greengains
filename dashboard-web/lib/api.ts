/**
 * GreenGains API Client
 * Connects to greengains.onrender.com backend
 */

const API_BASE_URL = 'https://greengains.onrender.com';

export interface AggregateData {
  window_start?: string;
  day?: string;
  geohash: string;
  samples_count: number;
  device_count: number;
  avg_light: number;
  avg_light_min?: number;
  avg_light_max?: number;
  movement_score: number;
  quality_valid_ratio: number;
}

export interface CoverageData {
  geohash: string;
  samples_count: number;
  device_hours: number;
  device_events: number;
  movement_score: number;
  quality_valid_ratio: number;
}

export interface DeviceStatsData {
  device_hash: string;
  samples_count: number;
  valid_samples: number;
  pocket_samples: number;
  uptime_seconds: number;
  last_upload_at: string;
}

export interface ApiResponse<T> {
  items: T[];
  next_cursor?: string;
}

/**
 * Fetch aggregates data
 */
export async function fetchAggregates(params: {
  apiKey: string;
  bucket?: '5m' | 'day';
  from?: string;
  to?: string;
  geohashPrefix?: string;
}): Promise<ApiResponse<AggregateData>> {
  const url = new URL('/analytics/aggregates', API_BASE_URL);

  if (params.bucket) url.searchParams.set('bucket', params.bucket);
  if (params.from) url.searchParams.set('from', params.from);
  if (params.to) url.searchParams.set('to', params.to);
  if (params.geohashPrefix) url.searchParams.set('geohashPrefix', params.geohashPrefix);

  const response = await fetch(url.toString(), {
    headers: {
      'Authorization': `Bearer ${params.apiKey}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    throw new Error(`API request failed: ${response.statusText}`);
  }

  return response.json();
}

/**
 * Fetch coverage data
 */
export async function fetchCoverage(params: {
  apiKey: string;
  from?: string;
  to?: string;
}): Promise<ApiResponse<CoverageData>> {
  const url = new URL('/analytics/coverage', API_BASE_URL);

  if (params.from) url.searchParams.set('from', params.from);
  if (params.to) url.searchParams.set('to', params.to);

  const response = await fetch(url.toString(), {
    headers: {
      'Authorization': `Bearer ${params.apiKey}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    throw new Error(`API request failed: ${response.statusText}`);
  }

  return response.json();
}

/**
 * Fetch device statistics
 */
export async function fetchDeviceStats(params: {
  apiKey: string;
  cursor?: string;
}): Promise<ApiResponse<DeviceStatsData>> {
  const url = new URL('/analytics/device-stats', API_BASE_URL);

  if (params.cursor) url.searchParams.set('cursor', params.cursor);

  const response = await fetch(url.toString(), {
    headers: {
      'Authorization': `Bearer ${params.apiKey}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    throw new Error(`API request failed: ${response.statusText}`);
  }

  return response.json();
}

/**
 * Format utilities
 */
export function formatNumber(num: number): string {
  if (num >= 1000000) return `${(num / 1000000).toFixed(1)}M`;
  if (num >= 1000) return `${(num / 1000).toFixed(1)}K`;
  return num.toString();
}

export function formatDateTime(date: string): string {
  return new Date(date).toLocaleString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function formatRelativeTime(date: string): string {
  const now = new Date();
  const then = new Date(date);
  const diffMs = now.getTime() - then.getTime();
  const diffMins = Math.floor(diffMs / 60000);

  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins}m ago`;

  const diffHours = Math.floor(diffMins / 60);
  if (diffHours < 24) return `${diffHours}h ago`;

  const diffDays = Math.floor(diffHours / 24);
  return `${diffDays}d ago`;
}
