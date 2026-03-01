// Initialize Sentry FIRST (before anything else!)
import * as Sentry from '@sentry/node';
import { nodeProfilingIntegration } from '@sentry/profiling-node';

Sentry.init({
  dsn: process.env.SENTRY_DSN || 'https://d0e924903d56b78ed1d576a92fc51826@o4510780171747328.ingest.de.sentry.io/4510780175941712',
  environment: process.env.NODE_ENV || 'development',
  integrations: [
    nodeProfilingIntegration(),
  ],
  tracesSampleRate: 0.1, // 10% of requests (free tier friendly)
  profilesSampleRate: 0.1,
});

import Fastify from 'fastify';
import crypto from 'crypto';
import cors from '@fastify/cors';
import rateLimit from '@fastify/rate-limit';
import { config, getAllowedOrigins } from './config';
import { initDatabase, closeDatabase } from './database';
import { initFirebase, isFirebaseInitialized } from './utils/firebase-auth';
import { runPendingMigrations } from './migrations';
import { deviceRoutes } from './routes/device';
import { uploadRoutes } from './routes/upload';
import { analyticsRoutes } from './routes/analytics';
import { userRoutes } from './routes/user';
import { authRoutes } from './routes/auth';
import { dataRoutes } from './routes/data';
import { referralRoutes } from './routes/referral';
import { startAggregationJob, stopAggregationJob } from './jobs/aggregator';
import { ErrorCodes, createErrorResponse } from './utils/errors';

const fastify = Fastify({
  logger: {
    level: config.nodeEnv === 'production' ? 'info' : 'debug',
    // Add request IDs for tracing
    genReqId: () => crypto.randomUUID(),
  },
  bodyLimit: 1048576 * 10, // 10MB limit for uploads
  // Disable Fastify's default error handler so Sentry can catch errors
  disableRequestLogging: false,
});

// Add Sentry error handler - catches all uncaught errors
fastify.setErrorHandler((error, request, reply) => {
  // Log to Sentry
  Sentry.captureException(error, {
    contexts: {
      request: {
        method: request.method,
        url: request.url,
        headers: request.headers,
      },
    },
    user: {
      id: (request as any).user?.uid,
    },
  });

  // Log to console (for Render logs)
  fastify.log.error({
    err: error,
    req: request,
    requestId: request.id,
  }, 'Unhandled error');

  // Return standardized error to client
  const statusCode = error.statusCode || 500;
  const errorResponse = createErrorResponse(
    ErrorCodes.INTERNAL_SERVER_ERROR,
    config.nodeEnv === 'production'
      ? 'An unexpected error occurred'
      : error.message,
    request.id
  );

  reply.status(statusCode).send(errorResponse);
});

// Configure raw body parser for upload endpoint - MOVED to upload.ts
// fastify.addContentTypeParser... removed

// Register CORS
fastify.register(cors, {
  origin: (() => {
    const origins = getAllowedOrigins();
    return origins.length > 0 ? origins : false; // false = disable CORS (same-origin only)
  })(),
  credentials: true,
});

// Register rate limiting
fastify.register(rateLimit, {
  max: config.rateLimitPerMinute,
  timeWindow: config.rateLimitWindowSeconds * 1000, // Convert to milliseconds
  cache: config.rateLimitCacheSize,
});

// Health check endpoint - tests database connectivity
fastify.get('/health', async (request, reply) => {
  const health: any = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    checks: {},
  };

  // Test database connection
  try {
    const { getPool } = await import('./database');
    const pool = getPool();
    const start = Date.now();
    await pool.query('SELECT 1');
    const latency = Date.now() - start;

    health.checks.database = {
      status: 'up',
      latency_ms: latency,
    };
  } catch (error) {
    health.status = 'unhealthy';
    health.checks.database = {
      status: 'down',
      error: error instanceof Error ? error.message : 'Unknown error',
    };
    // Return 503 Service Unavailable if DB is down
    reply.status(503);
  }

  // Check Firebase (non-critical)
  health.checks.firebase = {
    status: isFirebaseInitialized() ? 'enabled' : 'disabled',
  };

  return health;
});

// Register routes
fastify.register(authRoutes);
fastify.register(dataRoutes);
fastify.register(deviceRoutes);
fastify.register(uploadRoutes);
fastify.register(analyticsRoutes);
fastify.register(userRoutes);
fastify.register(referralRoutes);

// Graceful shutdown
const shutdown = async (signal: string) => {
  fastify.log.info({ signal }, 'Shutting down gracefully');
  try {
    await fastify.close();
    await stopAggregationJob();
    await closeDatabase();
    fastify.log.info('Server shut down successfully');
    process.exit(0);
  } catch (error) {
    fastify.log.error({ err: error }, 'Error during shutdown');
    process.exit(1);
  }
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Start server
const start = async () => {
  try {
    // Initialize database
    await initDatabase();

    // Run pending migrations
    await runPendingMigrations();

    // Initialize Firebase
    initFirebase();

    // Start aggregation job
    startAggregationJob().catch((error) =>
      fastify.log.error({ err: error }, 'Failed to start aggregation job'),
    );

    // Start listening
    await fastify.listen({
      port: config.port,
      host: '0.0.0.0',
    });

    fastify.log.info({
      port: config.port,
      env: config.nodeEnv,
      firebase: isFirebaseInitialized() ? 'enabled' : 'disabled',
    }, 'GreenGains backend running');
  } catch (error) {
    fastify.log.error({ err: error }, 'Failed to start server');
    process.exit(1);
  }
};

start();
