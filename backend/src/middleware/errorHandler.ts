import type { ErrorRequestHandler } from 'express';
import { logError } from '../config/logger';

export class AppError extends Error {
  readonly statusCode: number;
  readonly code: string;
  readonly details?: unknown;

  constructor(statusCode: number, code: string, message: string, details?: unknown) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
  }
}

export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  if (
    err instanceof SyntaxError &&
    'status' in err &&
    (err as { status?: number }).status === 400 &&
    'body' in err
  ) {
    res.status(400).json({
      error: {
        code: 'BAD_JSON',
        message: 'Malformed JSON body',
      },
    });
    return;
  }

  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      error: {
        code: err.code,
        message: err.message,
        details: err.details ?? null,
      },
    });
    return;
  }

  logError('Unhandled application error', {
    name: err instanceof Error ? err.name : 'UnknownError',
    message: err instanceof Error ? err.message : 'Unknown error',
    stack: err instanceof Error ? err.stack : null,
  });

  res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred',
    },
  });
};
