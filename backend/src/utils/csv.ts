/**
 * Minimal CSV encoder for query-result rows. Quotes every string, escapes
 * internal quotes, and defuses formula injection (leading =+-@) for anyone
 * opening the export in Excel/Sheets. Column order follows the first row's
 * key order, so callers control it via their SELECT.
 */
export function rowsToCsv(rows: Record<string, unknown>[]): string {
  if (rows.length === 0) return '';
  const headers = Object.keys(rows[0]);
  return [
    headers.join(','),
    ...rows.map((row) =>
      headers
        .map((h) => {
          const val = row[h];
          if (val === null || val === undefined) return '';
          if (typeof val === 'string') {
            const safe = val.replace(/^[=+\-@\t\r]/, "'$&");
            return `"${safe.replace(/"/g, '""')}"`;
          }
          return String(val);
        })
        .join(','),
    ),
  ].join('\n');
}
