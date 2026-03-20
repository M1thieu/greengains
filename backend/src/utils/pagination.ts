/**
 * Pagination Utilities
 *
 * Helpers for building cursor-based pagination queries.
 * Eliminates manual paramIndex tracking across analytics endpoints.
 */

/**
 * Query builder that manages parameter indexing automatically.
 * Prevents off-by-one errors with $1, $2, $3... parameter references.
 *
 * Usage:
 *   const qb = new QueryBuilder();
 *   qb.where('window_start >= $P', fromDate);
 *   qb.where('geohash LIKE $P', `${geohash}%`);
 *   const { whereSql, params, nextParamIndex } = qb.build();
 */
export class QueryBuilder {
  private clauses: string[] = [];
  private params: any[] = [];
  private paramIndex: number;

  constructor(startIndex: number = 1) {
    this.paramIndex = startIndex;
  }

  /**
   * Add a WHERE clause. Use $P as placeholder for the next parameter index.
   *
   * @param clause SQL clause with $P placeholders
   * @param values Parameter values (one per $P placeholder)
   */
  where(clause: string, ...values: any[]): this {
    let processedClause = clause;

    for (const value of values) {
      processedClause = processedClause.replace('$P', `$${this.paramIndex}`);
      this.params.push(value);
      this.paramIndex++;
    }

    this.clauses.push(processedClause);
    return this;
  }

  /**
   * Add a WHERE clause only if the condition value is truthy
   *
   * @param clause SQL clause with $P placeholders
   * @param condition Value to check (clause only added if truthy)
   * @param values Parameter values
   */
  whereIf(condition: any, clause: string, ...values: any[]): this {
    if (condition) {
      this.where(clause, ...values);
    }
    return this;
  }

  /**
   * Build the final WHERE SQL and parameters
   */
  build(): { whereSql: string; params: any[]; nextParamIndex: number } {
    return {
      whereSql: this.clauses.length > 0 ? `WHERE ${this.clauses.join(' AND ')}` : '',
      params: this.params,
      nextParamIndex: this.paramIndex,
    };
  }

}

/**
 * Generate a cursor string from the last row of a result set
 *
 * @param row Last row in result set
 * @param fields Array of field names to include in cursor
 * @returns Pipe-delimited cursor string, or null if row is missing
 */
export function generateCursor(row: any, fields: string[]): string | null {
  if (!row) return null;

  const values = fields.map((field) => {
    const value = row[field];
    if (value === null || value === undefined) return '';
    if (value instanceof Date) return value.toISOString();
    return String(value);
  });

  // Only generate cursor if at least one field has a value
  if (values.every((v) => v === '')) return null;

  return values.join('|');
}

/**
 * Parse a cursor string back into individual values
 *
 * @param cursor Pipe-delimited cursor string
 * @param expectedFields Number of expected fields
 * @returns Array of cursor values, or null if invalid
 */
export function parseCursor(cursor: string | undefined, expectedFields: number): string[] | null {
  if (!cursor) return null;

  const parts = cursor.split('|');
  if (parts.length !== expectedFields) return null;
  if (parts.some((p) => p === '')) return null;

  return parts;
}
