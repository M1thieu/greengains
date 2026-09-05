import { getPool } from '../database';
import { cellToStreetName } from '../utils/geocoding';

export interface WeeklyInsight {
  // Coverage delta
  newZonesThisWeek: number;
  totalZones: number;

  // Roughest zone the user mapped this week (named)
  roughestStreet: string | null;
  roughestVibration: number | null; // 0-1 normalised

  // How that compares to everyone else in the same cell
  roughestPercentile: number | null; // e.g. 87 = top 13% roughest

  // Light pollution highlight
  brightestStreet: string | null;
  brightestLux: number | null;

  // Solo territory
  soloZones: number; // zones only this user has ever mapped

  // Transport mode breakdown (0–100, null if no data)
  walkingPct: number | null;

  // Week dates
  weekStart: string;
  weekEnd: string;
}

function weekBounds(): { start: Date; end: Date; prevStart: Date; prevEnd: Date } {
  const now = new Date();
  const day = now.getUTCDay(); // 0 = Sun
  const monday = new Date(now);
  monday.setUTCDate(now.getUTCDate() - ((day + 6) % 7));
  monday.setUTCHours(0, 0, 0, 0);

  const sunday = new Date(monday);
  sunday.setUTCDate(monday.getUTCDate() + 6);
  sunday.setUTCHours(23, 59, 59, 999);

  const prevMonday = new Date(monday);
  prevMonday.setUTCDate(monday.getUTCDate() - 7);
  const prevSunday = new Date(monday);
  prevSunday.setUTCDate(monday.getUTCDate() - 1);
  prevSunday.setUTCHours(23, 59, 59, 999);

  return { start: monday, end: sunday, prevStart: prevMonday, prevEnd: prevSunday };
}

export async function computeWeeklyInsight(userId: string): Promise<WeeklyInsight | null> {
  const pool = getPool();
  const { start, end, prevStart, prevEnd } = weekBounds();

  try {
    // 1. This week's distinct cells + their avg vibration (vehicle-only) + avg lux (night-only)
    const thisWeekResult = await pool.query<{
      h3_res9: string;
      avg_vibration: string;
      avg_lux: string;
      avg_lux_night: string;
    }>(`
      SELECT
        h3_res9,
        AVG(CASE WHEN batch_json->'summary'->>'transport_mode' = 'vehicle'
            THEN (batch_json->'summary'->>'accel_std_dev')::float END)                     AS avg_vibration,
        AVG((batch_json->'summary'->'light'->>'avg')::float)                               AS avg_lux,
        AVG(CASE WHEN EXTRACT(hour FROM timestamp_utc) >= 22
                   OR EXTRACT(hour FROM timestamp_utc) < 6
            THEN (batch_json->'summary'->'light'->>'avg')::float END)                      AS avg_lux_night
      FROM sensor_batches
      WHERE user_id     = $1
        AND h3_res9     IS NOT NULL
        AND timestamp_utc >= $2
        AND timestamp_utc <= $3
      GROUP BY h3_res9
    `, [userId, start.toISOString(), end.toISOString()]);

    if (thisWeekResult.rows.length === 0) return null;

    // 2. Last week's cells (to compute delta)
    const lastWeekResult = await pool.query<{ h3_res9: string }>(`
      SELECT DISTINCT h3_res9
      FROM sensor_batches
      WHERE user_id     = $1
        AND h3_res9     IS NOT NULL
        AND timestamp_utc >= $2
        AND timestamp_utc <= $3
    `, [userId, prevStart.toISOString(), prevEnd.toISOString()]);

    const lastWeekCells = new Set(lastWeekResult.rows.map(r => r.h3_res9));
    const thisWeekCells = thisWeekResult.rows.map(r => r.h3_res9);
    const newZones = thisWeekCells.filter(c => !lastWeekCells.has(c)).length;

    // 3. Total lifetime zones
    const totalResult = await pool.query<{ count: string }>(
      `SELECT COUNT(DISTINCT h3_res9)::text AS count FROM sensor_batches WHERE user_id = $1 AND h3_res9 IS NOT NULL`,
      [userId]
    );
    const totalZones = parseInt(totalResult.rows[0]?.count ?? '0', 10);

    // 4. Solo zones (only this user ever mapped them)
    const soloResult = await pool.query<{ count: string }>(`
      WITH my_cells AS (
        SELECT DISTINCT h3_res9 FROM sensor_batches WHERE user_id = $1 AND h3_res9 IS NOT NULL LIMIT 5000
      )
      SELECT COUNT(*)::text AS count
      FROM my_cells mc
      WHERE (
        SELECT COUNT(DISTINCT user_id) FROM sensor_batches sb
        WHERE sb.h3_res9 = mc.h3_res9
      ) = 1
    `, [userId]);
    const soloZones = parseInt(soloResult.rows[0]?.count ?? '0', 10);

    // 5. Roughest (vehicle-only vibration) and brightest (night lux) cells this week
    const withVibration = thisWeekResult.rows.filter(r => r.avg_vibration != null);
    const roughestRow = withVibration.sort(
      (a, b) => parseFloat(b.avg_vibration) - parseFloat(a.avg_vibration)
    )[0] ?? null;

    // Prefer night lux for light pollution insight; fall back to all-hours lux
    const brightestRow = [...thisWeekResult.rows].sort(
      (a, b) => parseFloat(b.avg_lux_night ?? b.avg_lux ?? '0') - parseFloat(a.avg_lux_night ?? a.avg_lux ?? '0')
    )[0] ?? null;

    // 6. Community percentile for roughest cell (vehicle-only)
    let roughestPercentile: number | null = null;
    if (roughestRow) {
      const pctResult = await pool.query<{ percentile: string }>(`
        SELECT ROUND(
          100.0 * PERCENT_RANK() OVER (
            ORDER BY AVG(CASE WHEN batch_json->'summary'->>'transport_mode' = 'vehicle'
                         THEN (batch_json->'summary'->>'accel_std_dev')::float END) DESC
          )
        )::text AS percentile
        FROM sensor_batches
        WHERE h3_res9 = $1 AND h3_res9 IS NOT NULL
        GROUP BY user_id
        HAVING AVG(CASE WHEN batch_json->'summary'->>'transport_mode' = 'vehicle'
                   THEN (batch_json->'summary'->>'accel_std_dev')::float END) <= $2
        LIMIT 1
      `, [roughestRow.h3_res9, parseFloat(roughestRow.avg_vibration)]);
      roughestPercentile = pctResult.rows[0]
        ? Math.round(100 - parseFloat(pctResult.rows[0].percentile))
        : null;
    }

    // 7. Transport mode breakdown for this week's batches
    const transportResult = await pool.query<{
      walking: string; vehicle: string; total: string;
    }>(`
      SELECT
        COUNT(CASE WHEN batch_json->'summary'->>'transport_mode' = 'walking' THEN 1 END)::text AS walking,
        COUNT(CASE WHEN batch_json->'summary'->>'transport_mode' = 'vehicle' THEN 1 END)::text AS vehicle,
        COUNT(*)::text AS total
      FROM sensor_batches
      WHERE user_id = $1 AND timestamp_utc >= $2 AND timestamp_utc <= $3
    `, [userId, start.toISOString(), end.toISOString()]);
    const tRow = transportResult.rows[0];
    const totalBatches = parseInt(tRow?.total ?? '0', 10);
    const walkingBatches = parseInt(tRow?.walking ?? '0', 10);
    const walkingPct = totalBatches >= 5
      ? Math.round((walkingBatches / totalBatches) * 100)
      : null;

    // 8. Resolve street names (max 2 Nominatim calls)
    const cellsToName = [
      roughestRow?.h3_res9,
      brightestRow?.h3_res9 !== roughestRow?.h3_res9 ? brightestRow?.h3_res9 : null,
    ].filter(Boolean) as string[];

    const names = await Promise.all(cellsToName.map(c => cellToStreetName(c)));
    const nameMap = new Map(cellsToName.map((c, i) => [c, names[i]]));

    return {
      newZonesThisWeek: newZones,
      totalZones,
      soloZones,
      roughestStreet:     roughestRow ? (nameMap.get(roughestRow.h3_res9) ?? null) : null,
      roughestVibration:  roughestRow ? parseFloat(roughestRow.avg_vibration) : null,
      roughestPercentile,
      brightestStreet:    brightestRow ? (nameMap.get(brightestRow.h3_res9) ?? null) : null,
      brightestLux:       brightestRow ? parseFloat(brightestRow.avg_lux_night ?? brightestRow.avg_lux) : null,
      walkingPct,
      weekStart: start.toISOString().slice(0, 10),
      weekEnd:   end.toISOString().slice(0, 10),
    };
  } catch (err) {
    return null;
  }
}
