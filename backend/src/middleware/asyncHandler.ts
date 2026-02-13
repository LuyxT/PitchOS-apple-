import type { NextFunction, Request, Response, RequestHandler } from 'express';
import type { ZodSchema } from 'zod';
import { AppError } from './errorHandler';

export function asyncHandler(
  fn: (req: Request, res: Response, next: NextFunction) => Promise<void>
): RequestHandler {
  return (req, res, next) => {
    void fn(req, res, next).catch(next);
  };
}

export function validate(schema: ZodSchema, source: 'body' | 'query' | 'params' = 'body'): RequestHandler {
  return (req, _res, next) => {
    const result = schema.safeParse(req[source]);
    if (!result.success) {
      const details = result.error.errors.map((e) => ({
        path: e.path.join('.'),
        message: e.message,
      }));
      next(new AppError(400, 'VALIDATION_ERROR', 'Request validation failed', details));
      return;
    }
    // Replace the source with parsed (and coerced) data
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (req as any)[source] = result.data;
    next();
  };
}
