/**
 * Standard error codes for the API
 * Based on Stripe/Anthropic API patterns
 */

export const ErrorCodes = {
  // Authentication errors (4xx)
  INVALID_API_KEY: 'INVALID_API_KEY',
  UNAUTHORIZED: 'UNAUTHORIZED',
  FORBIDDEN: 'FORBIDDEN',

  // Rate limiting (429)
  RATE_LIMIT_EXCEEDED: 'RATE_LIMIT_EXCEEDED',

  // Validation errors (400)
  INVALID_REQUEST: 'INVALID_REQUEST',
  VALIDATION_ERROR: 'VALIDATION_ERROR',

  // Resource errors (404)
  NOT_FOUND: 'NOT_FOUND',

  // Server errors (5xx)
  INTERNAL_SERVER_ERROR: 'INTERNAL_SERVER_ERROR',
  DATABASE_ERROR: 'DATABASE_ERROR',
  SERVICE_UNAVAILABLE: 'SERVICE_UNAVAILABLE',
} as const;

export type ErrorCode = typeof ErrorCodes[keyof typeof ErrorCodes];

/**
 * Create a standardized error response
 */
export function createErrorResponse(
  code: ErrorCode,
  message: string,
  requestId?: string,
  details?: unknown
): { error: ErrorCode; message: string; requestId?: string; details?: unknown } {
  const response: { error: ErrorCode; message: string; requestId?: string; details?: unknown } = {
    error: code,
    message,
  };

  if (requestId) response.requestId = requestId;
  if (details !== undefined) response.details = details;

  return response;
}

/**
 * Log and reply with a standardized 500 Internal Server Error.
 * Use instead of inline reply.code(500).send({...}) to ensure requestId is always included.
 */
export function internalError(
  reply: { code: (n: number) => { send: (body: unknown) => unknown } },
  request: { id: string },
  log: { error: (...args: unknown[]) => void },
  context: string,
  err: unknown,
) {
  log.error({ err, requestId: request.id }, `${context} failed`);
  return reply.code(500).send({ error: 'Internal Server Error', requestId: request.id });
}

/**
 * Get HTTP status code for error code
 */
export function getStatusCode(code: ErrorCode): number {
  switch (code) {
    case ErrorCodes.INVALID_API_KEY:
    case ErrorCodes.UNAUTHORIZED:
      return 401;
    case ErrorCodes.FORBIDDEN:
      return 403;
    case ErrorCodes.NOT_FOUND:
      return 404;
    case ErrorCodes.RATE_LIMIT_EXCEEDED:
      return 429;
    case ErrorCodes.INVALID_REQUEST:
    case ErrorCodes.VALIDATION_ERROR:
      return 400;
    case ErrorCodes.DATABASE_ERROR:
    case ErrorCodes.INTERNAL_SERVER_ERROR:
      return 500;
    case ErrorCodes.SERVICE_UNAVAILABLE:
      return 503;
    default:
      return 500;
  }
}
