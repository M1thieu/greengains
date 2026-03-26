import { Pool, PoolClient } from 'pg';
import { config } from './config';

let pool: Pool | null = null;

export async function initDatabase(): Promise<void> {
  if (pool) return;

  pool = new Pool({
    connectionString: config.databaseUrl,
    min: 2,
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
    // keepAlive must be off for Transaction pooler (PgBouncer) — it resets
    // the server-side connection after each transaction, making keepalive packets
    // arrive on a different backend socket than the one that sent them.
    keepAlive: false,
    ssl: {
      rejectUnauthorized: false, // Supabase pooler requires SSL
    },
  });

  // Handle pool errors
  pool.on('error', (err) => {
    console.error('Unexpected pool error:', err);
  });

  // Test connection — retry with backoff for Render cold-start / Supabase warmup.
  // pg-pool will auto-reconnect at query time; this just validates the config early.
  const maxAttempts = 5;
  const baseDelayMs = 2000;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const client = await pool.connect();
      console.log('✅ Database connected successfully');
      client.release();
      return;
    } catch (error) {
      if (attempt === maxAttempts) {
        console.error(`❌ Database connection failed after ${maxAttempts} attempts:`, error);
        throw error;
      }
      const delay = baseDelayMs * attempt; // 2s, 4s, 6s, 8s
      console.warn(`⚠️  DB connect attempt ${attempt}/${maxAttempts} failed — retrying in ${delay}ms`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}

export async function closeDatabase(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
    console.log('Database pool closed');
  }
}

export function getPool(): Pool {
  if (!pool) {
    throw new Error('Database pool not initialized. Call initDatabase() first.');
  }
  return pool;
}

export async function getClient(): Promise<PoolClient> {
  const pool = getPool();
  return await pool.connect();
}

// Helper for running queries
export async function query<T = any>(text: string, params?: any[]): Promise<T[]> {
  const pool = getPool();
  const result = await pool.query(text, params);
  return result.rows;
}
