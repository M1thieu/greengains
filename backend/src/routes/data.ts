import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import { getPool } from '../database';
import { verifyFirebaseToken } from '../utils/firebase-auth';
import { QueryBuilder, generateCursor, parseCursor } from '../utils/pagination';

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

function numOrNull(value: any): number | null {
  return value !== null && value !== undefined ? Number(value) : null;
}

/**
 * Get subscription tier for an organization
 * Returns 'free' tier if user has no organization (fallback for new users)
 */
async function getOrgSubscriptionTier(pool: any, userId: string): Promise<string> {
  try {
    const result = await pool.query(
      `SELECT s.tier FROM subscriptions s
       JOIN organizations o ON s.organization_id = o.id
       JOIN organization_members om ON o.id = om.organization_id
       WHERE om.user_id = $1 AND om.accepted_at IS NOT NULL
       ORDER BY o.created_at ASC
       LIMIT 1`,
      [userId]
    );

    return result.rows[0]?.tier || 'free';
  } catch (error) {
    // If tables don't exist or user has no org, return free tier
    console.warn('Could not determine subscription tier, defaulting to free:', error);
    return 'free';
  }
}

/**
 * Get user's primary organization
 */
async function getUserOrgId(pool: any, userId: string): Promise<string | null> {
  const result = await pool.query(
    `SELECT o.id FROM organizations o
     JOIN organization_members om ON o.id = om.organization_id
     WHERE om.user_id = $1 AND om.accepted_at IS NOT NULL
     ORDER BY o.created_at ASC
     LIMIT 1`,
    [userId]
  );

  return result.rows[0]?.id || null;
}

export async function dataRoutes(fastify: FastifyInstance) {
  const pool = getPool();

  /**
   * GET /api/v1/data/aggregated
   * Get aggregated sensor data with quality filtering
   * Tier-aware: free=7 days, pro=90 days, enterprise=365 days
   */
  fastify.get(
    '/api/v1/data/aggregated',
    { preHandler: (req, reply) => verifyFirebaseToken(req, reply) },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request as any).user?.uid;
      if (!userId) {
        return reply.code(401).send({ error: 'Unauthorized' });
      }

      try {
        const query = dataAggregatesSchema.parse(request.query);
        const pool = getPool();

        // Get user's subscription tier
        const tier = await getOrgSubscriptionTier(pool, userId);

        // Determine max history based on tier
        const historyDays: Record<string, number> = {
          free: 7,
          pro: 90,
          enterprise: 365,
        };
        const maxDays = historyDays[tier] || 7;

        // Build query
        const table = query.bucket === 'day' ? 'sensor_aggregates_daily' : 'sensor_aggregates_5m';
        const timeColumn = query.bucket === 'day' ? 'day' : 'window_start';
        const qb = new QueryBuilder();

        // Apply time filters
        const fromTime = query.from ? new Date(query.from) : new Date(Date.now() - maxDays * 86400000);
        const toTime = query.to ? new Date(query.to) : new Date();

        qb.where(`${timeColumn} >= $P`, fromTime.toISOString());
        qb.where(`${timeColumn} <= $P`, toTime.toISOString());

        // Apply geohash filter
        qb.whereIf(query.geohash, `geohash LIKE $P`, query.geohash ? `${query.geohash}%` : undefined);

        // Apply precision filter (new feature)
        qb.whereIf(query.min_precision > 0, `precision_score >= $P`, query.min_precision);

        // Cursor-based pagination
        const cursorParts = parseCursor(query.cursor, 2);
        if (cursorParts) {
          qb.where(`(${timeColumn}, geohash) > ($P, $P)`, cursorParts[0], cursorParts[1]);
        }

        const { whereSql, params, nextParamIndex } = qb.build();
        params.push(query.limit + 1); // +1 to detect if there's a next page

        const sql = `
          SELECT
            window_start, window_end, day,
            geohash,
            samples_count, device_count,
            avg_light, avg_light_min, avg_light_max,
            avg_accel_rms, avg_gyro_rms, movement_score,
            battery_avg, location_share, device_hours,
            precision_score, sensor_count, coverage_hours
          FROM ${table}
          ${whereSql}
          ORDER BY ${timeColumn} ASC, geohash ASC
          LIMIT $${nextParamIndex}
        `;

        const result = await pool.query(sql, params);

        // Check if there's a next page
        const hasNextPage = result.rows.length > query.limit;
        const items = result.rows.slice(0, query.limit).map((row) => ({
          timestamp: row.window_start || row.day,
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
          precision_score: numOrNull(row.precision_score),
          sensor_count: numOrNull(row.sensor_count),
          coverage_hours: numOrNull(row.coverage_hours),
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
        fastify.log.error(error);
        return reply.code(500).send({ error: 'Internal Server Error' });
      }
    }
  );

  /**
   * GET /api/v1/data/readings/:sensor
   * Get sensor readings with time filtering
   */
  fastify.get(
    '/api/v1/data/readings/:sensor',
    { preHandler: (req, reply) => verifyFirebaseToken(req, reply) },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request as any).user?.uid;
      if (!userId) {
        return reply.code(401).send({ error: 'Unauthorized' });
      }

      try {
        const { sensor } = request.params as { sensor: string };
        const query = dataAggregatesSchema.parse(request.query);
        const pool = getPool();

        // For now, return mock readings (sensor_batches table has raw data but needs aggregation)
        const readings = [];
        const now = new Date();
        for (let i = 100; i >= 0; i--) {
          const time = new Date(now.getTime() - i * 60000);
          readings.push({
            timestamp: time.toISOString(),
            [sensor]: Math.random() * 100,
          });
        }

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
    { preHandler: (req, reply) => verifyFirebaseToken(req, reply) },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = (request as any).user?.uid;
      if (!userId) {
        return reply.code(401).send({ error: 'Unauthorized' });
      }

      try {
        const query = exportSchema.parse(request.body);
        const pool = getPool();

        // Get user's subscription tier
        const tier = await getOrgSubscriptionTier(pool, userId);

        // Check export permission
        if (tier === 'free') {
          return reply.code(403).send({
            error: 'Export not available on free tier',
            message: 'Upgrade to Pro to export data',
          });
        }

        // Determine row limit based on tier
        const rowLimits: Record<string, number> = {
          pro: 100000,
          enterprise: 1000000,
        };
        const maxRows = rowLimits[tier] || 0;

        // Build query
        const timeColumn = 'window_start';
        const qb = new QueryBuilder();

        const fromTime = query.from ? new Date(query.from) : new Date(Date.now() - 90 * 86400000);
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
            precision_score
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
                  if (typeof val === 'string' && val.includes(',')) return `"${val}"`;
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
}
