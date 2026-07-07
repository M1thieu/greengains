import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { cellToLatLng } from 'h3-js';
import { getPool } from '../database';

interface RoadQualityRow {
  h3_res9: string;
  vibration_score: string;
  sample_count: string;
  last_seen: string;
}

interface BboxQuery {
  sw_lat?: string;
  sw_lng?: string;
  ne_lat?: string;
  ne_lng?: string;
}

/**
 * Public road quality tile endpoint — no auth required.
 * Returns aggregated vibration scores per H3 res-9 cell (~174m hex).
 * Designed for telematics, insurance, and routing API consumers.
 *
 * Optional bbox filter: ?sw_lat=&sw_lng=&ne_lat=&ne_lng=
 * Without bbox, returns all cells with ≥3 samples in the last 30 days.
 * Max 10,000 cells returned.
 */
export async function roadQualityRoutes(fastify: FastifyInstance) {
  fastify.get(
    '/api/tiles/road-quality',
    async (request: FastifyRequest<{ Querystring: BboxQuery }>, reply: FastifyReply) => {
      const pool = getPool();

      const rows = await pool.query<RoadQualityRow>(`
        SELECT
          h3_res9,
          ROUND(AVG((batch_json->>'avgVibration')::float)::numeric, 4) AS vibration_score,
          COUNT(*)::text AS sample_count,
          MAX(timestamp_utc)::text AS last_seen
        FROM sensor_batches
        WHERE h3_res9 IS NOT NULL
          AND timestamp_utc >= NOW() - INTERVAL '30 days'
          AND batch_json ? 'avgVibration'
          AND (batch_json->>'avgVibration')::float > 0
        GROUP BY h3_res9
        HAVING COUNT(*) >= 3
        ORDER BY AVG((batch_json->>'avgVibration')::float) DESC
        LIMIT 10000
      `);

      const { sw_lat, sw_lng, ne_lat, ne_lng } = request.query;
      const hasBbox =
        sw_lat !== undefined &&
        sw_lng !== undefined &&
        ne_lat !== undefined &&
        ne_lng !== undefined;

      let tiles = rows.rows.map(r => {
        const [lat, lng] = cellToLatLng(r.h3_res9);
        return {
          h3:       r.h3_res9,
          lat:      Math.round(lat * 1e6) / 1e6,
          lng:      Math.round(lng * 1e6) / 1e6,
          vibration: parseFloat(r.vibration_score),
          samples:  parseInt(r.sample_count, 10),
          lastSeen: r.last_seen.slice(0, 10),
        };
      });

      if (hasBbox) {
        const swLat = parseFloat(sw_lat!);
        const swLng = parseFloat(sw_lng!);
        const neLat = parseFloat(ne_lat!);
        const neLng = parseFloat(ne_lng!);
        if (!isNaN(swLat) && !isNaN(swLng) && !isNaN(neLat) && !isNaN(neLng)) {
          tiles = tiles.filter(
            t => t.lat >= swLat && t.lat <= neLat && t.lng >= swLng && t.lng <= neLng,
          );
        }
      }

      reply.header('Cache-Control', 'public, max-age=300');
      return reply.send({
        resolution: 9,
        hexSize:    '~174m',
        window:     '30d',
        count:      tiles.length,
        tiles,
      });
    },
  );
}
