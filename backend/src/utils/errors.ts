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

