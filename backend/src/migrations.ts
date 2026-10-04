import { getPool } from './database';
import * as fs from 'fs';
import * as path from 'path';

interface Migration {
  filename: string;
  sql: string;
}

/**
 * Auto-migration system
 * Runs all pending SQL migrations from backend/db folder on startup
 */
export async function runPendingMigrations(): Promise<void> {
  const pool = getPool();

  try {
    // Create migrations tracking table if it doesn't exist
    await pool.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        filename TEXT PRIMARY KEY,
        applied_at TIMESTAMP NOT NULL DEFAULT NOW()
      )
    `);

    // Read all migration files from db folder
    const migrationsDir = path.join(__dirname, '..', 'db');

    if (!fs.existsSync(migrationsDir)) {
      console.log('No migrations directory found, skipping migrations');
      return;
    }

    const files = fs.readdirSync(migrationsDir)
      .filter(f => f.endsWith('.sql'))
      .sort(); // Run in chronological order (filename prefix like 20260111_)

    if (files.length === 0) {
      console.log('No migration files found');
      return;
    }

    // Get already-applied migrations
    const { rows: applied } = await pool.query<{ filename: string }>(
      'SELECT filename FROM schema_migrations'
    );
    const appliedSet = new Set(applied.map(r => r.filename));

    // Find pending migrations
    const pending: Migration[] = [];
    for (const filename of files) {
      if (!appliedSet.has(filename)) {
        const filepath = path.join(migrationsDir, filename);
        const sql = fs.readFileSync(filepath, 'utf-8');
        pending.push({ filename, sql });
      }
    }

    if (pending.length === 0) {
      console.log('✅ All migrations up to date');
      return;
    }

    console.log(`📦 Running ${pending.length} pending migration(s)...`);

    // Run each pending migration in a transaction
    for (const migration of pending) {
      const client = await pool.connect();
      try {
        await client.query('BEGIN');

        console.log(`  ⏳ Applying: ${migration.filename}`);
        await client.query(migration.sql);

        // Mark as applied
        await client.query(
          'INSERT INTO schema_migrations (filename) VALUES ($1)',
          [migration.filename]
        );

        await client.query('COMMIT');
        console.log(`  ✅ Applied: ${migration.filename}`);
      } catch (error) {
        await client.query('ROLLBACK');
        console.error(`  ❌ Failed to apply ${migration.filename}:`, error);
        throw error; // Stop on first error
      } finally {
        client.release();
      }
    }

    console.log('✅ All migrations completed successfully');
  } catch (error) {
    console.error('Migration error:', error);
    throw error;
  }
}
