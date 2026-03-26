import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import { getPool } from '../database';
import { requireFirebaseAuth } from '../middleware/auth';
import { QueryBuilder, generateCursor, parseCursor } from '../utils/pagination';
import { numOrNull } from '../utils/response-utils';
import {
  getOrgSubscriptionTier,
  requireTier,
  TIER_HISTORY_DAYS,
  TIER_EXPORT_ROWS,
  type SubscriptionTier,
} from '../utils/tier-utils';
import { MS_PER_DAY, MS_PER_HOUR } from '../constants';

/**
 * Data Routes - Dashboard/Client Data Endpoints
 * Tier-aware aggregated data queries with quality filtering
 */

const dataAggregatesSchema = z.object({
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  geohash: z.string().max(12).optional(),
  min_precision: z.coerce.number().min(0).max(1).default(0),
  bucket: z.enum(['5m', 'day']).default('5m'),
  limit: z.coerce.number().int().min(1).max(500).default(200),
  cursor: z.string().optional(),
});

const exportSchema = z.object({
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  geohash: z.string().max(12).optional(),
  format: z.enum(['csv', 'json']).default('csv'),
});


export async function dataRoutes(fastify: FastifyInstance) {
  /**
   * GET /api/v1/data/aggregated
   * Get aggregated sensor data with quality filtering
   * Tier-aware: free=7 days, pro=90 days, enterprise=365 days
   */
  fastify.get(
    '/api/v1/data/aggregated',
    { preHandler: requireFirebaseAuth },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.uid;

      try {
        const pool = getPool();
        const query = dataAggregatesSchema.parse(request.query);

        // Get user's subscription tier
        const tier = await getOrgSubscriptionTier(pool, userId);

        const maxDays = TIER_HISTORY_DAYS[tier as SubscriptionTier] ?? 7;

        // Build query
        const table = query.bucket === 'day' ? 'sensor_aggregates_daily' : 'sensor_aggregates_5m';
        const timeColumn = query.bucket === 'day' ? 'day' : 'window_start';
        const qb = new QueryBuilder();

        // Apply time filters
        const fromTime = query.from ? new Date(query.from) : new Date(Date.now() - maxDays * MS_PER_DAY);
        const toTime = query.to ? new Date(query.to) : new Date();

        qb.where(`${timeColumn} >= $P`, fromTime.toISOString());
        qb.where(`${timeColumn} <= $P`, toTime.toISOString());

        qb.whereIf(query.geohash, `geohash LIKE $P`, query.geohash ? `${query.geohash}%` : undefined);

        // Cursor-based pagination
        const cursorParts = parseCursor(query.cursor, 2);
        if (cursorParts) {
          qb.where(`(${timeColumn}, geohash) > ($P, $P)`, cursorParts[0], cursorParts[1]);
        }

        const { whereSql, params, nextParamIndex } = qb.build();
        params.push(query.limit + 1); // +1 to detect if there's a next page

        // Build SELECT columns based on table - 5m uses window_start/end, daily uses day
        const timeColumns = query.bucket === 'day'
          ? 'day'
          : 'window_start, window_end';

        // Build SELECT columns - some only exist in certain tables
        const dataColumns = `
          samples_count, device_count,
          avg_light, avg_light_min, avg_light_max,
          avg_accel_rms, avg_gyro_rms, movement_score,
          battery_avg, location_share,
          ${query.bucket === 'day' ? 'device_hours' : 'NULL::DOUBLE PRECISION as device_hours'},
          quality_samples, quality_valid_ratio, quality_pocket_ratio
        `;

        const sql = `
          SELECT
            ${timeColumns},
            geohash,
            ${dataColumns}
          FROM ${table}
          ${whereSql}
          ORDER BY ${timeColumn} ASC, geohash ASC
          LIMIT $${nextParamIndex}
        `;

        const result = await pool.query(sql, params);

        // Check if there's a next page
        const hasNextPage = result.rows.length > query.limit;
        const items = result.rows.slice(0, query.limit).map((row) => ({
          timestamp: row.window_start || row.day,  // window_start for 5m, day for daily
          geohash: row.geohash,
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
        const next_cursor = hasNextPage && lastItem ? generateCursor(lastItem, ['timestamp', 'geohash']) : null;

        return reply.send({
          tier,
          data_retention_days: maxDays,
          items,
          next_cursor,
          has_more: hasNextPage,
        });
      } catch (error) {
        if (error instanceof z.ZodError) {
          return reply.code(422).send({ error: 'Validation Error', details: error.errors });
        }
        const errorMsg = error instanceof Error ? error.message : String(error);
        fastify.log.error({ err: error }, '/api/v1/data/aggregated failed');
        return reply.code(500).send({ error: 'Internal Server Error', details: errorMsg });
      }
    }
  );

  /**
   * GET /api/v1/data/readings/:sensor
   * Get time-series sensor readings from 5m aggregates
   */
  fastify.get(
    '/api/v1/data/readings/:sensor',
    { preHandler: requireFirebaseAuth },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.uid;

      try {
        const pool = getPool();
        const { sensor } = request.params as { sensor: string };
        const query = dataAggregatesSchema.parse(request.query);

        // Map sensor name to DB column (same columns exist in both 5m and daily tables)
        const sensorColumnMap: Record<string, string> = {
          Light: 'avg_light',
          Movement: 'movement_score',
          Pressure: 'avg_gyro_rms',
          Quality: 'quality_valid_ratio',
          light: 'avg_light',
          movement: 'movement_score',
          pressure: 'avg_gyro_rms',
          quality: 'quality_valid_ratio',
        };

        const column = sensorColumnMap[sensor] || 'avg_light';

        const tier = await getOrgSubscriptionTier(pool, userId);
        const maxDays = TIER_HISTORY_DAYS[tier] ?? 7;

        // Use daily aggregates for wide ranges — same pattern as /aggregated endpoint
        const isDailyBucket = query.bucket === 'day';
        const table = isDailyBucket ? 'sensor_aggregates_daily' : 'sensor_aggregates_5m';
        const timeColumn = isDailyBucket ? 'day' : 'window_start';

        // Build query
        const qb = new QueryBuilder();
        const fromTime = query.from ? new Date(query.from) : new Date(Date.now() - maxDays * MS_PER_DAY);
        const toTime = query.to ? new Date(query.to) : new Date();

        qb.where(`${timeColumn} >= $P`, fromTime.toISOString());
        qb.where(`${timeColumn} <= $P`, toTime.toISOString());
        qb.whereIf(query.geohash, `geohash LIKE $P`, query.geohash ? `${query.geohash}%` : undefined);

        const { whereSql, params, nextParamIndex } = qb.build();
        params.push(query.limit);

        const sql = `
          SELECT
            ${timeColumn} as timestamp,
            ${column} as value
          FROM ${table}
          ${whereSql}
          ORDER BY ${timeColumn} ASC
          LIMIT $${nextParamIndex}
        `;

        const result = await pool.query(sql, params);

        // Return array of { timestamp, value }
        const readings = result.rows.map((row) => ({
          timestamp: row.timestamp,
          value: numOrNull(row.value),
        }));

        return reply.send(readings);
      } catch (error) {
        if (error instanceof z.ZodError) {
          return reply.code(422).send({ error: 'Validation Error', details: error.errors });
        }
        fastify.log.error(error);
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    }
  );

  /**
   * POST /api/v1/data/export
   * Export data as CSV or JSON
   * Tier-aware: free=disabled, pro=100K rows max, enterprise=unlimited
   */
  fastify.post(
    '/api/v1/data/export',
    // requireTier('pro') gates at preHandler level (DIMO pattern) — defense in depth
    { preHandler: [requireFirebaseAuth, requireTier('pro')] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.uid;

      try {
        const pool = getPool();
        const query = exportSchema.parse(request.body);

        // Get user's subscription tier (still needed for row-limit enforcement)
        const tier = await getOrgSubscriptionTier(pool, userId);

        const maxRows = TIER_EXPORT_ROWS[tier] ?? 0;

        // Build query
        const timeColumn = 'window_start';
        const qb = new QueryBuilder();

        const fromTime = query.from ? new Date(query.from) : new Date(Date.now() - 90 * MS_PER_DAY);
        const toTime = query.to ? new Date(query.to) : new Date();

        qb.where(`${timeColumn} >= $P`, fromTime.toISOString());
        qb.where(`${timeColumn} <= $P`, toTime.toISOString());
        qb.whereIf(query.geohash, `geohash LIKE $P`, query.geohash ? `${query.geohash}%` : undefined);

        const { whereSql, params, nextParamIndex } = qb.build();
        params.push(maxRows + 1); // +1 to check if we hit limit

        const sql = `
          SELECT
            window_start, geohash,
            samples_count, device_count,
            avg_light, avg_light_min, avg_light_max,
            avg_accel_rms, avg_gyro_rms, movement_score,
            battery_avg, location_share,
            quality_samples, quality_valid_ratio, quality_pocket_ratio
          FROM sensor_aggregates_5m
          ${whereSql}
          ORDER BY window_start DESC, geohash ASC
          LIMIT $${nextParamIndex}
        `;

        const result = await pool.query(sql, params);

        if (result.rows.length > maxRows) {
          return reply.code(413).send({
            error: 'Export exceeds tier limit',
            message: `Pro tier limited to ${maxRows.toLocaleString()} rows. Contact support for enterprise exports.`,
            rows_returned: result.rows.length,
            limit: maxRows,
          });
        }

        // Format response
        if (query.format === 'json') {
          return reply.send({
            tier,
            count: result.rows.length,
            data: result.rows,
            exported_at: new Date().toISOString(),
          });
        } else {
          // CSV format
          if (result.rows.length === 0) {
            return reply
              .header('Content-Type', 'text/csv')
              .header('Content-Disposition', 'attachment; filename="data.csv"')
              .send('No data available for the selected time range');
          }

          // Build CSV
          const headers = Object.keys(result.rows[0]);
          const csv = [
            headers.join(','),
            ...result.rows.map((row) =>
              headers
                .map((h) => {
                  const val = row[h];
                  if (val === null || val === undefined) return '';
                  if (typeof val === 'string') {
                    // Quote all strings; escape internal quotes; strip leading =+-@ to prevent formula injection
                    const safe = val.replace(/^[=+\-@\t\r]/, "'$&");
                    return `"${safe.replace(/"/g, '""')}"`;
                  }
                  return val;
                })
                .join(',')
            ),
          ].join('\n');

          return reply
            .header('Content-Type', 'text/csv; charset=utf-8')
            .header('Content-Disposition', `attachment; filename="greengains-export-${Date.now()}.csv"`)
            .send(csv);
        }
      } catch (error) {
        if (error instanceof z.ZodError) {
          return reply.code(422).send({ error: 'Validation Error', details: error.errors });
        }
        fastify.log.error(error);
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    }
  );

  /**
   * GET /api/v1/data/coverage
   * Get per-geohash coverage statistics for the dashboard
   */
  fastify.get(
    '/api/v1/data/coverage',
    { preHandler: requireFirebaseAuth },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.uid;

      try {
        const pool = getPool();
        const query = z.object({
          hours: z.coerce.number().int().min(1).max(2190).default(24),
          min_devices: z.coerce.number().int().min(0).default(0),
        }).parse(request.query);

        const fromTime = new Date(Date.now() - query.hours * MS_PER_HOUR);

        // Use daily aggregates for wide ranges — 5m table may not retain data beyond ~7d
        // and scanning thousands of 5m windows is slow. Daily table is pre-aggregated.
        const useDaily = query.hours > 168;

        const sql = useDaily ? `
          SELECT
            geohash,
            SUM(samples_count) as samples_count,
            SUM(device_count) as device_count,
            SUM(device_hours) as device_hours,
            AVG(avg_light) as avg_light,
            MAX(quality_valid_ratio) as quality_valid_ratio,
            MAX(day) as last_seen
          FROM sensor_aggregates_daily
          WHERE day >= $1
          GROUP BY geohash
          HAVING SUM(device_count) >= $2
          ORDER BY SUM(device_count) DESC
        ` : `
          SELECT
            geohash,
            SUM(samples_count) as samples_count,
            SUM(device_count) as device_count,
            SUM(device_count) * 5 / 60 as device_hours,
            AVG(avg_light) as avg_light,
            MAX(quality_valid_ratio) as quality_valid_ratio,
            MAX(window_start) as last_seen
          FROM sensor_aggregates_5m
          WHERE window_start >= $1
          GROUP BY geohash
          HAVING MAX(device_count) >= $2
          ORDER BY device_count DESC
        `;

        const result = await pool.query(sql, [fromTime.toISOString(), query.min_devices]);

        const items = result.rows.map((row) => ({
          geohash: row.geohash,
          samples_count: Number(row.samples_count),
          device_hours: Math.round(Number(row.device_hours) * 100) / 100,
          avg_light: numOrNull(row.avg_light),
          quality_valid_ratio: numOrNull(row.quality_valid_ratio),
          last_seen: row.last_seen,
        }));

        return reply.send({
          hours: query.hours,
          min_devices: query.min_devices,
          items,
        });
      } catch (error) {
        if (error instanceof z.ZodError) {
          return reply.code(422).send({ error: 'Validation Error', details: error.errors });
        }
        fastify.log.error(error);
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    }
  );
}
