import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { requireFirebaseAuth } from '../middleware/auth';
import { computeWeeklyInsight } from '../jobs/weekly-insights';

export async function insightsRoutes(fastify: FastifyInstance) {
  /**
   * GET /api/user/insights/weekly
   * Returns a structured weekly insight for the authenticated user.
   * Includes street names, vibration percentile, new zones, solo territory.
   */
  fastify.get(
    '/api/user/insights/weekly',
    { preHandler: requireFirebaseAuth },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.uid;
      const insight = await computeWeeklyInsight(userId);

      if (!insight) {
        return reply.send({ hasActivity: false });
      }

      return reply.send({ hasActivity: true, ...insight });
    }
  );
}
