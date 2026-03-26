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
      // Only select rows with valid numeric lat/lon — prevents infinite loop if
      // a row has location={"lat": null} or a non-numeric value (cast → NULL
      // which IS NOT NULL returns false, skipping those rows permanently).
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
         WHERE h3_res9 IS NULL
           AND (batch_json->'location'->>'lat')::float IS NOT NULL
           AND (batch_json->'location'->>'lon')::float IS NOT NULL
           AND ABS((batch_json->'location'->>'lat')::float) <= 90
           AND ABS((batch_json->'location'->>'lon')::float) <= 180
         LIMIT $1`,
        [BATCH_SIZE],
      );
      if ((rows.rowCount ?? 0) === 0) break;

      const deviceHashes: string[] = [];
      const timestamps: Date[] = [];
      const h3r9s: string[] = [];
      const h3r8s: string[] = [];

      for (const r of rows.rows) {
        if (!isFinite(r.lat) || !isFinite(r.lon)) continue; // skip Inf/NaN from DB
        try {
          deviceHashes.push(r.device_hash);
          timestamps.push(r.timestamp_utc);
          h3r9s.push(latLngToCell(r.lat, r.lon, 9));
          h3r8s.push(latLngToCell(r.lat, r.lon, 8));
        } catch {
          // Out-of-range coordinates — skip this row; it will remain h3_res9=NULL
          // and be excluded by the WHERE clause on next startup (::float IS NOT NULL
          // would still select it, so stamp a sentinel or just leave it — acceptable
          // since it's a data quality issue in the source batch).
        }
      }

      if (deviceHashes.length === 0) break; // all rows in this chunk were invalid

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

    // Compute H3 indices in JS, then bulk UPDATE both tables with UNNEST —
    // 2 queries total instead of 2×N (N+1 → constant).
    const resolvedGeohashes: string[] = [];
    const resolvedH3Indexes: string[] = [];

    for (const row of geohashes.rows) {
      const centroid = decodeGeohash(row.geohash);
      if (!centroid) continue;
      resolvedGeohashes.push(row.geohash);
      resolvedH3Indexes.push(latLngToCell(centroid.lat, centroid.lon, 9));
    }

    if (resolvedGeohashes.length > 0) {
      await pool.query(
        `UPDATE sensor_aggregates_5m AS t
            SET h3_index = u.h3idx
          FROM UNNEST($1::text[], $2::text[]) AS u(gh, h3idx)
          WHERE t.geohash = u.gh AND t.h3_index IS NULL`,
        [resolvedGeohashes, resolvedH3Indexes],
      );
      await pool.query(
        `UPDATE sensor_aggregates_daily AS t
            SET h3_index = u.h3idx
          FROM UNNEST($1::text[], $2::text[]) AS u(gh, h3idx)
          WHERE t.geohash = u.gh AND t.h3_index IS NULL`,
        [resolvedGeohashes, resolvedH3Indexes],
      );
    }
    console.log(`[h3-backfill] aggregates done: ${resolvedGeohashes.length} geohashes updated`);
  }
}
