import { z } from 'zod';

export const LocationDataSchema = z.object({
  lat: z.number().min(-90).max(90),
  lon: z.number().min(-180).max(180),
  altitude: z.number().optional(),
  accuracy_m: z.number(),
  speed_mps: z.number().optional(),
  bearing_deg: z.number().optional(),
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

export const SensorReadingSchema = z.object({
  t: z.coerce.date(),
  light: z.number().optional(),
  accel: z.array(z.number()).length(3).optional(),
  gyro: z.array(z.number()).length(3).optional(),
  // [x, y, z, magnitude] in µT — magnitude pre-computed on device to avoid backend recomputation
  magnetic: z.array(z.number()).length(4).optional(),
  pressure: z.number().optional(),
  quality: QualityMetadataSchema.optional(),
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
});

export type LocationData = z.infer<typeof LocationDataSchema>;
export type SensorReading = z.infer<typeof SensorReadingSchema>;
export type QualityMetadata = z.infer<typeof QualityMetadataSchema>;
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
    gyro_rms: number;
    pressure?: { avg: number; min: number; max: number };
    magnetic_magnitude?: { avg: number; min: number; max: number };
    quality_valid: number;
    quality_pocket_likely: number;
  };
  batch: SensorReading[];
  location?: LocationData;
  geohash?: string;
  battery_level?: number;
  is_charging?: boolean;
}
