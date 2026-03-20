/**
 * One-time H3 backfill — runs at server startup after migrations.
 *
 * Populates:
 *   sensor_batches.h3_res9 / h3_res8  — for rows that have location in batch_json
 *   sensor_aggregates_5m.h3_index      — derived from geohash centroid at res 9
 *   sensor_aggregates_daily.h3_index   — same
 *
 * No-op if all rows are already populated.
 * Processes sensor_batches in chunks of 500 to avoid long-running transactions.
 * Aggregate backfill works by distinct geohash (small set, single-pass).
 */

import { latLngToCell } from 'h3-js';
import { getPool } from '../database';
import { decodeGeohash } from '../utils/geo';

const BATCH_SIZE = 500;

export async function runH3Backfill(): Promise<void> {
  const pool = getPool();

  // ── 1. sensor_batches ────────────────────────────────────────────────────
  const batchCheck = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count
     FROM sensor_batches
     WHERE h3_res9 IS NULL AND batch_json->'location' IS NOT NULL`,
  );
  const batchPending = parseInt(batchCheck.rows[0].count, 10);

  if (batchPending > 0) {
    console.log(`[h3-backfill] Backfilling H3 for ${batchPending} sensor_batches rows...`);
    let processed = 0;

    while (true) {
      const rows = await pool.query<{
        device_hash: string;
        timestamp_utc: Date;
        lat: number;
        lon: number;
      }>(
        `SELECT device_hash, timestamp_utc,
                (batch_json->'location'->>'lat')::float AS lat,
                (batch_json->'location'->>'lon')::float AS lon
         FROM sensor_batches
         WHERE h3_res9 IS NULL AND batch_json->'location' IS NOT NULL
         LIMIT $1`,
        [BATCH_SIZE],
      );
      if ((rows.rowCount ?? 0) === 0) break;

      const deviceHashes = rows.rows.map(r => r.device_hash);
      const timestamps   = rows.rows.map(r => r.timestamp_utc);
      const h3r9s        = rows.rows.map(r => latLngToCell(r.lat, r.lon, 9));
      const h3r8s        = rows.rows.map(r => latLngToCell(r.lat, r.lon, 8));

      await pool.query(
        `UPDATE sensor_batches
           SET h3_res9 = u.h3r9, h3_res8 = u.h3r8
         FROM UNNEST($1::text[], $2::timestamptz[], $3::text[], $4::text[])
              AS u(dh, ts, h3r9, h3r8)
         WHERE sensor_batches.device_hash = u.dh
           AND sensor_batches.timestamp_utc = u.ts`,
        [deviceHashes, timestamps, h3r9s, h3r8s],
      );
      processed += rows.rowCount ?? 0;
    }
    console.log(`[h3-backfill] sensor_batches done: ${processed} rows updated`);
  }

  // ── 2. Aggregate tables — by distinct geohash (small set, one decode per cell) ──
  const aggCheck = await pool.query<{ count: string }>(
    `SELECT COUNT(DISTINCT geohash)::text AS count
     FROM sensor_aggregates_5m
     WHERE h3_index IS NULL`,
  );
  const aggPending = parseInt(aggCheck.rows[0].count, 10);

  if (aggPending > 0) {
    console.log(`[h3-backfill] Backfilling h3_index for ${aggPending} geohashes in aggregates...`);

    const geohashes = await pool.query<{ geohash: string }>(
      `SELECT DISTINCT geohash FROM sensor_aggregates_5m WHERE h3_index IS NULL`,
    );

    for (const row of geohashes.rows) {
      const centroid = decodeGeohash(row.geohash);
      if (!centroid) continue;
      const h3Index = latLngToCell(centroid.lat, centroid.lon, 9);

      await pool.query(
        `UPDATE sensor_aggregates_5m
            SET h3_index = $1
          WHERE geohash = $2 AND h3_index IS NULL`,
        [h3Index, row.geohash],
      );
      await pool.query(
        `UPDATE sensor_aggregates_daily
            SET h3_index = $1
          WHERE geohash = $2 AND h3_index IS NULL`,
        [h3Index, row.geohash],
      );
    }
    console.log(`[h3-backfill] aggregates done: ${geohashes.rowCount} geohashes updated`);
  }
}
