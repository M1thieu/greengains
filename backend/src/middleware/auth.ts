/**
 * Authentication Middleware
 *
 * Fastify preHandler hooks for Firebase authentication.
 * Centralizes auth logic that was previously duplicated across route files.
 */

import { FastifyRequest, FastifyReply } from 'fastify';
import { verifyFirebaseToken, requireAuth } from '../utils/firebase-auth';
import { getPool } from '../database';

// Extend FastifyRequest to include user context
declare module 'fastify' {
  interface FastifyRequest {
    user?: {
      uid: string;
    };
  }
}

/**
 * Middleware: Require Firebase authentication
 * Throws 401 if no valid token is provided
 *
 * Usage:
 * fastify.get('/protected', { preHandler: requireFirebaseAuth }, handler)
 */
export async function requireFirebaseAuth(
  request: FastifyRequest,
  reply: FastifyReply
): Promise<void> {
  const uid = await requireAuth(request, reply);
  request.user = { uid };
}

/**
 * Middleware: Optional Firebase authentication
 * Sets request.user if token is valid, null otherwise
 * Does NOT throw - allows anonymous access
 *
 * Usage:
 * fastify.get('/public-or-authed', { preHandler: optionalFirebaseAuth }, handler)
 */
export async function optionalFirebaseAuth(
  request: FastifyRequest,
  reply: FastifyReply
): Promise<void> {
  try {
    const uid = await verifyFirebaseToken(request, reply);
    if (uid) {
      request.user = { uid };
    }
  } catch {
    // Ignore auth errors - allow anonymous access
    request.user = undefined;
  }
}

/**
 * Middleware: Device Secret OR Firebase Token authentication
 * Used for /upload endpoint - allows both auth methods
 *
 * Priority:
 * 1. X-Device-Secret header (long-lived device credentials)
 * 2. Firebase Bearer token (standard user auth)
 *
 * Usage:
 * fastify.post('/upload', { preHandler: deviceOrFirebaseAuth }, handler)
 */
export async function deviceOrFirebaseAuth(
  request: FastifyRequest,
  reply: FastifyReply
): Promise<void> {
  const deviceSecret = request.headers['x-device-secret'] as string | undefined;

  // Try Device Secret first (faster, doesn't require Firebase SDK call)
  if (deviceSecret) {
    try {
      const pool = getPool();
      const result = await pool.query(
        'SELECT user_id FROM device_secrets WHERE secret = $1',
        [deviceSecret]
      );

      if (result.rows.length > 0) {
        const userId = result.rows[0].user_id;
        request.user = { uid: userId };

        // Update last_used_at timestamp (fire and forget)
        pool.query(
          'UPDATE device_secrets SET last_used_at = NOW() WHERE secret = $1',
          [deviceSecret]
        ).catch((err) => {
          console.error('Failed to update device secret last_used_at:', err);
        });

        return; // Successfully authenticated via device secret
      }

      // Invalid device secret - fall through to Firebase auth
      console.warn('Invalid Device Secret provided:', deviceSecret.substring(0, 8) + '...');
    } catch (e) {
      console.error('Device Secret verification failed:', e);
      // Fall through to Firebase auth
    }
  }

  // Fallback to Firebase Token authentication
  await requireFirebaseAuth(request, reply);
}
