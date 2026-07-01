import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';

const pageviewSchema = z.object({
  url:      z.string().max(512).optional(),
  referrer: z.string().max(512).optional(),
  lang:     z.enum(['en', 'fr']).optional(),
  w:        z.number().int().min(0).max(10000).optional(),
  // ua intentionally dropped — not stored, not logged
});

export async function telemetryRoutes(fastify: FastifyInstance) {
  // POST /api/telemetry/pageview — unauthenticated, CORS open, fire-and-forget
  fastify.route({
    method:  ['POST', 'OPTIONS'],
    url:     '/api/telemetry/pageview',
    config:  { rateLimit: { max: 30, timeWindow: '1 minute' } },
    // Open CORS for this path (public static sites)
    preHandler: async (request: FastifyRequest, reply: FastifyReply) => {
      reply.header('Access-Control-Allow-Origin', '*');
      reply.header('Access-Control-Allow-Methods', 'POST, OPTIONS');
      reply.header('Access-Control-Allow-Headers', 'Content-Type');
      if (request.method === 'OPTIONS') { reply.code(204).send(); }
    },
    handler: async (request: FastifyRequest, reply: FastifyReply) => {
      try {
        const body = pageviewSchema.safeParse(request.body);
        if (!body.success) { reply.code(400).send(); return; }

        const { url, referrer, lang, w } = body.data;

        // Structured log — queryable in Railway log explorer, no PII
        request.log.info({
          event:    'pageview',
          url:      url?.slice(0, 200) ?? null,
          referrer: referrer?.slice(0, 200) ?? null,
          lang:     lang ?? null,
          viewport: w ?? null,
        });

        reply.code(204).send();
      } catch {
        reply.code(204).send(); // Always 204 — telemetry must never block UI
      }
    },
  });
}
