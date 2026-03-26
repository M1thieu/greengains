import { FastifyInstance } from 'fastify';
import { MS_PER_HOUR } from '../constants';
import { z } from 'zod';
import { getPool } from '../database';
import { AGGREGATION_WINDOW_MINUTES } from '../jobs/aggregator';
import { verifyAnalyticsApiKey } from '../utils/security';
import { QueryBuilder, generateCursor, parseCursor } from '../utils/pagination';
import { numOrNull } from '../utils/response-utils';

const aggregatesQuerySchema = z.object({
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  geohash: z.string().max(12).optional(),
  bucket: z.enum(['5m', 'day']).default('5m'),
  limit: z.coerce.number().int().min(1).max(500).default(200),
  cursor: z.string().optional(),
});

const coverageQuerySchema = z.object({
  hours: z.coerce.number().int().min(1).max(168).default(24),
  min_devices: z.coerce.number().int().min(0).default(0),
  precision: z.coerce.number().int().min(1).max(12).default(6),
});

const deviceStatsQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(500).default(100),
  cursor: z.string().optional(),
});

export async function analyticsRoutes(fastify: FastifyInstance) {
  fastify.get('/analytics/aggregates', { preHandler: verifyAnalyticsApiKey }, async (request) => {
    const pool = getPool();
    const query = aggregatesQuerySchema.parse(request.query);
    const table = query.bucket === 'day' ? 'sensor_aggregates_daily' : 'sensor_aggregates_5m';
    const timeColumn = query.bucket === 'day' ? 'day' : 'window_start';

    const qb = new QueryBuilder();

    qb.whereIf(query.from, `${timeColumn} >= $P`, query.from);
    qb.whereIf(query.to, `${timeColumn} <= $P`, query.to);
    qb.whereIf(query.geohash, `geohash LIKE $P`, query.geohash ? `${query.geohash}%` : undefined);

    // Cursor-based pagination
    const cursorParts = parseCursor(query.cursor, 2);
    if (cursorParts) {
      qb.where(`(${timeColumn}, geohash) > ($P, $P)`, cursorParts[0], cursorParts[1]);
    }

    const { whereSql, params, nextParamIndex } = qb.build();
    params.push(query.limit);

    const sql = `
      SELECT *
      FROM ${table}
      ${whereSql}
      ORDER BY ${timeColumn} ASC, geohash ASC
      LIMIT $${nextParamIndex}
    `;

    const result = await pool.query(sql, params);

    const items = result.rows.map((row) => ({
      ...row,
      samples_count: Number(row.samples_count),
      device_count: Number(row.device_count),
      avg_light: numOrNull(row.avg_light),
      avg_light_min: numOrNull(row.avg_light_min),
      avg_light_max: numOrNull(row.avg_light_max),
      avg_accel_rms: numOrNull(row.avg_accel_rms),
      avg_gyro_rms: numOrNull(row.avg_gyro_rms),
      movement_score: numOrNull(row.movement_score),
      battery_avg: numOrNull(row.battery_avg),
      location_share: numOrNull(row.location_share),
      device_hours: numOrNull(row.device_hours),
      quality_samples: numOrNull(row.quality_samples),
      quality_valid_ratio: numOrNull(row.quality_valid_ratio),
      quality_pocket_ratio: numOrNull(row.quality_pocket_ratio),
    }));

    const lastItem = items[items.length - 1];
    const cursorTimeField = query.bucket === 'day' ? 'day' : 'window_start';
    const next_cursor = generateCursor(lastItem, [cursorTimeField, 'geohash']);

    return {
      bucket: query.bucket,
      items,
      next_cursor,
    };
  });

  fastify.get('/analytics/coverage', { preHandler: verifyAnalyticsApiKey }, async (request) => {
    const pool = getPool();
    const query = coverageQuerySchema.parse(request.query);
    const now = new Date();
    const from = new Date(now.getTime() - query.hours * MS_PER_HOUR);

    const result = await pool.query(
      `
        SELECT
          geohash,
          SUM(samples_count) AS samples_count,
          SUM(device_count) AS device_events,
          SUM(device_count * ${AGGREGATION_WINDOW_MINUTES}) / 60.0 AS device_hours,
          AVG(avg_light) AS avg_light,
          AVG(avg_accel_rms) AS avg_accel_rms,
          AVG(avg_gyro_rms) AS avg_gyro_rms,
          AVG(movement_score) AS movement_score,
          AVG(location_share) AS location_share,
          SUM(quality_samples) AS quality_samples,
          AVG(quality_valid_ratio) AS quality_valid_ratio,
          AVG(quality_pocket_ratio) AS quality_pocket_ratio
        FROM sensor_aggregates_5m
        WHERE window_start >= $1
        GROUP BY geohash
      `,
      [from.toISOString()],
    );

    const items = result.rows
      .map((row) => ({
        geohash: row.geohash,
        samples_count: Number(row.samples_count),
        device_events: Number(row.device_events),
        device_hours: Number(row.device_hours),
        avg_light: numOrNull(row.avg_light),
        avg_accel_rms: numOrNull(row.avg_accel_rms),
        avg_gyro_rms: numOrNull(row.avg_gyro_rms),
        movement_score: numOrNull(row.movement_score),
        location_share: numOrNull(row.location_share),
        quality_samples: numOrNull(row.quality_samples),
        quality_valid_ratio: numOrNull(row.quality_valid_ratio),
        quality_pocket_ratio: numOrNull(row.quality_pocket_ratio),
      }))
      .filter((item) => item.device_events >= query.min_devices)
      .sort((a, b) => b.device_events - a.device_events);

    return {
      from: from.toISOString(),
      to: now.toISOString(),
      items,
    };
  });

  fastify.get('/analytics/device-stats', { preHandler: verifyAnalyticsApiKey }, async (request) => {
    const pool = getPool();
    const query = deviceStatsQuerySchema.parse(request.query);

    const qb = new QueryBuilder();

    // Cursor-based pagination (descending order)
    const cursorParts = parseCursor(query.cursor, 2);
    if (cursorParts) {
      qb.where(
        `(COALESCE(last_upload_at, '1970-01-01'), device_hash) < ($P, $P)`,
        cursorParts[0],
        cursorParts[1]
      );
    }

    const { whereSql, params, nextParamIndex } = qb.build();
    params.push(query.limit);

    const sql = `
      SELECT device_hash, samples_count, valid_samples, pocket_samples, uptime_seconds, last_upload_at
      FROM user_stats
      ${whereSql}
      ORDER BY COALESCE(last_upload_at, '1970-01-01') DESC, device_hash DESC
      LIMIT $${nextParamIndex}
    `;

    const result = await pool.query(sql, params);

    const items = result.rows.map((row) => ({
      device_hash: row.device_hash,
      samples_count: Number(row.samples_count),
      valid_samples: Number(row.valid_samples),
      pocket_samples: Number(row.pocket_samples),
      uptime_seconds: Number(row.uptime_seconds),
      last_upload_at: row.last_upload_at ? row.last_upload_at.toISOString() : null,
    }));

    const last = items[items.length - 1];
    const next_cursor = generateCursor(last, ['last_upload_at', 'device_hash']);

    return {
      items,
      next_cursor,
    };
  });
}
