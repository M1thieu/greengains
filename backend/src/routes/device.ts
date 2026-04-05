import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import * as crypto from 'crypto';
import * as admin from 'firebase-admin';
import { getPool } from '../database';
import { DeviceRegistrationSchema, DeviceRegistration } from '../models/device';
import { MAX_DEVICES_PER_USER } from '../constants';

export async function deviceRoutes(fastify: FastifyInstance) {
    fastify.post(
        '/register-device',
        {
            config: { rateLimit: { max: 5, timeWindow: '1 hour' } },
        },
        async (request: FastifyRequest, reply: FastifyReply) => {
            try {
                let bodyData = request.body;
                if (Buffer.isBuffer(bodyData)) {
                    bodyData = JSON.parse(bodyData.toString());
                }
                const body = DeviceRegistrationSchema.parse(bodyData);
                const { device_id, firebase_token } = body;

                // 1. Verify Firebase Token
                let userId: string;
                try {
                    const decodedToken = await admin.auth().verifyIdToken(firebase_token);
                    userId = decodedToken.uid;
                } catch (error) {
                    return reply.code(401).send({ error: 'Unauthorized', message: 'Invalid Firebase token' });
                }

                // 2. Enforce max devices per user — evict oldest if over limit
                const pool = getPool();
                const deviceCount = await pool.query<{ count: string }>(
                    `SELECT COUNT(*)::text AS count
                       FROM device_secrets
                      WHERE user_id = $1
                        AND device_id != $2`,
                    [userId, device_id],
                );
                if (parseInt(deviceCount.rows[0]?.count ?? '0', 10) >= MAX_DEVICES_PER_USER) {
                    // Evict the oldest device instead of hard-blocking
                    await pool.query(
                        `DELETE FROM device_secrets
                          WHERE user_id = $1
                            AND device_id != $2
                            AND device_id = (
                                SELECT device_id FROM device_secrets
                                 WHERE user_id = $1
                                   AND device_id != $2
                                 ORDER BY last_used_at ASC NULLS FIRST
                                 LIMIT 1
                            )`,
                        [userId, device_id],
                    );
                    request.log.info({ userId }, 'Evicted oldest device (limit reached)');
                }

                // 3. Generate Device Secret
                const deviceSecret = crypto.randomBytes(32).toString('hex');

                // 4. Store in DB
                await pool.query(
                    `INSERT INTO device_secrets (device_id, user_id, secret)
           VALUES ($1, $2, $3)
           ON CONFLICT (device_id)
           DO UPDATE SET
             user_id = EXCLUDED.user_id,
             secret = EXCLUDED.secret,
             last_used_at = NOW()`,
                    [device_id, userId, deviceSecret]
                );

                request.log.info({ device_id, userId }, 'Device registered');

                // 4. Return Secret
                return reply.code(200).send({ device_secret: deviceSecret });

            } catch (error: unknown) {
                request.log.error({ err: error }, 'Device registration error');
                const zodError = error as { issues?: unknown };
                if (zodError.issues) {
                    return reply.code(422).send({ error: 'Validation Error', details: zodError.issues });
                }
                return reply.code(500).send({ error: 'Internal Server Error' });
            }
        }
    );
}
