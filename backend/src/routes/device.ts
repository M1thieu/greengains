import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import * as crypto from 'crypto';
import * as admin from 'firebase-admin';
import { getPool } from '../database';
import { DeviceRegistrationSchema, DeviceRegistration } from '../models/device';

export async function deviceRoutes(fastify: FastifyInstance) {
    fastify.post(
        '/register-device',
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

                // 2. Generate Device Secret
                const deviceSecret = crypto.randomBytes(32).toString('hex');

                // 3. Store in DB
                const pool = getPool();
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

            } catch (error: any) {
                request.log.error({ err: error }, 'Device registration error');
                if (error.issues) {
                    return reply.code(422).send({ error: 'Validation Error', details: error.issues });
                }
                return reply.code(500).send({ error: 'Internal Server Error' });
            }
        }
    );
}
