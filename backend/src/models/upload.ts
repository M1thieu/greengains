import { z } from 'zod';

export const LocationDataSchema = z.object({
  lat: z.number().min(-90).max(90),
  lon: z.number().min(-180).max(180),
  altitude: z.number().optional(),
  accuracy_m: z.number(),
  speed_mps: z.number().optional(),
  bearing_deg: z.number().optional(),
  /**
   * RMS distance in metres of the batch's individual fixes from the reported centroid. A batch
   * is stored as ONE point, so this is how much travel that point hides (a 5-min walk ~100+ m,
   * a stand-still ~0). Optional and additive: nothing has to read it yet.
   */
  spread_m: z.number().min(0).max(1_000_000).optional().catch(undefined),
});

const OrientationEnum = z.enum([
  'face_up',
  'face_down',
  'upright_portrait',
  'upright_landscape',
  'upright_unknown',
  'unknown',
]);

const MotionStateEnum = z.enum(['unknown', 'stationary', 'light', 'active']);
const PocketStateEnum = z.enum(['unknown', 'likely', 'unlikely']);
const LocationQualityEnum = z.enum(['none', 'stale', 'high', 'medium', 'low', 'poor']);

export const QualityMetadataSchema = z.object({
  orientation: OrientationEnum.optional(),
  tilt_deg: z.number().optional(),
  motion_state: MotionStateEnum.optional(),
  motion_confidence: z.number().min(0).max(1).optional(),
  pocket: PocketStateEnum.optional(),
  location_quality: LocationQualityEnum.optional(),
  sample_count: z.number().int().positive().optional(),
  proximity_near: z.boolean().optional(),
});

/**
 * Extra channels that only SOME phones have: ambient temperature, relative humidity, a second
 * (rear) light sensor, sensor-chip temperatures. Generic on purpose — a new sensor needs no
 * server change, only a new key. Keys are lowercase snake_case, values finite numbers, at most
 * MAX_AUX_CHANNELS of them. Anything else drops this map and never the reading: an optional
 * channel must not be able to cost us the core sensor data. Value ranges are validated by
 * whoever consumes a given key, because a generic map cannot know that humidity is 0-100 and
 * a chip temperature can legitimately exceed any ambient record.
 */
const MAX_AUX_CHANNELS = 16;
const AuxChannelsSchema = z
  .record(z.string().regex(/^[a-z][a-z0-9_]{0,31}$/), z.number().finite().min(-1e6).max(1e9))
  .refine(o => Object.keys(o).length <= MAX_AUX_CHANNELS);

export const SensorReadingSchema = z.object({
  t: z.coerce.date(),
  light: z.number().optional(),
  aux: AuxChannelsSchema.optional().catch(undefined),
  accel: z.array(z.number()).length(3).optional(),
  gyro: z.array(z.number()).length(3).optional(),
  // [x, y, z, magnitude] in µT — magnitude pre-computed on device to avoid backend recomputation
  magnetic: z.array(z.number()).length(4).optional(),
  pressure: z.number().optional(),
  quality: QualityMetadataSchema.optional(),
});

/**
 * Connectivity context the client attaches to each batch. Pure telemetry: coarse and
 * categorical, no SSID / BSSID / cell identity. Delta fields count what happened since
 * the client's previous SUCCESSFUL upload, so a burst of failures while offline is
 * reported by the first batch that gets through.
 */
export const NetworkTelemetrySchema = z.object({
  transport: z.enum(['none', 'wifi', 'cellular', 'ethernet', 'vpn', 'other']).optional(),
  /** System-verified internet reachability (not just "connected"). */
  validated: z.boolean().optional(),
  metered: z.boolean().optional(),
  roaming: z.boolean().optional(),
  /** Android's own link-speed estimates in kbps — estimates only, 0 = unspecified. */
  down_kbps: z.number().int().min(0).max(10_000_000).optional(),
  up_kbps: z.number().int().min(0).max(10_000_000).optional(),
  /** 1 = first attempt; >1 means earlier attempts failed. */
  attempt: z.number().int().min(1).max(50).optional(),
  /** Age in seconds of the oldest reading at send time — delay caused by deferral. */
  queued_s: z.number().int().min(0).max(30 * 24 * 3600).optional(),
  /** Round-trip ms and compressed bytes of the previous successful upload. */
  last_upload_ms: z.number().int().min(0).max(600_000).optional(),
  last_upload_bytes: z.number().int().min(0).max(50_000_000).optional(),
  /** Default-network changes (wifi<->cellular, loss, validation flips). */
  transitions: z.number().int().min(0).max(100_000).optional(),
  /** Seconds with no validated network. */
  unusable_s: z.number().int().min(0).max(30 * 24 * 3600).optional(),
  /** Attempts cut short because the network changed mid-request (not the batch's fault). */
  interrupted: z.number().int().min(0).max(100_000).optional(),
  failed: z.number().int().min(0).max(100_000).optional(),
  dropped_readings: z.number().int().min(0).max(1_000_000).optional(),
  dropped_batches: z.number().int().min(0).max(100_000).optional(),
});

export const DeviceInfoSchema = z.object({
  manufacturer: z.string().max(64),
  model: z.string().max(64),
  sdk: z.number().int().min(1).max(100),
});

export const UploadBatchSchema = z.object({
  device_id: z.string().min(1).max(128),
  /** Stable UUID frozen at batch creation on the client. Never changes on retry.
   *  Stored in batch_json; the (device_hash, timestamp_utc) unique index deduplicates
   *  retries as long as the client sends the same frozen timestamp. */
  batch_id: z.string().uuid().optional(),
  timestamp: z.coerce.date()
    .refine(d => d <= new Date(Date.now() + 5 * 60_000), { message: 'Timestamp too far in future' })
    .refine(d => d >= new Date(Date.now() - 30 * 24 * 3600_000), { message: 'Timestamp too old' }),
  batch: z.array(SensorReadingSchema).min(1).max(500),
  location: LocationDataSchema.optional(),
  geohash: z.string().max(12).optional(),
  battery_level: z.number().min(-1).max(100).optional(),
  is_charging: z.boolean().optional(),
  /** WiFi signal strength in dBm at upload time. Null if not on WiFi. Range: -30 (excellent) to -90 (poor). */
  wifi_rssi_avg: z.number().int().min(-127).max(0).optional(),
  /** Count of visible WiFi access points at upload time. Urban density proxy — no SSIDs or MACs stored. */
  wifi_ap_count: z.number().int().min(0).max(500).optional(),
  /** Bitmask: LIGHT=1, MOTION=2, PRESSURE=4, GYRO=8, MAGNETIC=16 */
  sensor_flags: z.number().int().min(0).max(31).optional(),
  /** .catch(undefined): telemetry is best-effort — a malformed block must never cost us the sensor data. */
  network: NetworkTelemetrySchema.optional().catch(undefined),
  /** Phone model, kept per batch (as NoiseCapture and WeatherXM do) so sensor
   *  readings can be corrected per model. Best-effort like `network`. */
  device: DeviceInfoSchema.optional().catch(undefined),
});

export type LocationData = z.infer<typeof LocationDataSchema>;
export type SensorReading = z.infer<typeof SensorReadingSchema>;
export type QualityMetadata = z.infer<typeof QualityMetadataSchema>;
export type NetworkTelemetry = z.infer<typeof NetworkTelemetrySchema>;
export type UploadBatch = z.infer<typeof UploadBatchSchema>;

/** Shape of the JSONB payload stored in sensor_batches.batch_json */
export interface StoragePayload {
  timestamp: Date;
  summary: {
    count: number;
    period_start: Date;
    period_end: Date;
    light?: { avg: number; min: number; max: number };
    accel_rms: number;
    accel_std_dev: number;
    gyro_rms: number;
    pressure?: { avg: number; min: number; max: number };
    magnetic_magnitude?: { avg: number; min: number; max: number };
    quality_valid: number;
    quality_pocket_likely: number;
    /** Inferred from GPS speed: stationary / walking / vehicle / unknown */
    transport_mode?: string;
  };
  batch: SensorReading[];
  location?: LocationData;
  geohash?: string;
  battery_level?: number;
  is_charging?: boolean;
  wifi_rssi_avg?: number;
  wifi_ap_count?: number;
  network?: NetworkTelemetry;
  device?: z.infer<typeof DeviceInfoSchema>;
  quality_multiplier?: number;
}
