import { NextFunction, Response } from 'express';
import { randomUUID } from 'crypto';
import { RequestWithContext } from '../interfaces/request-context.interface';
import { structuredLog } from '../logging/structured-log';

export function requestIdMiddleware(
  req: RequestWithContext,
  res: Response,
  next: NextFunction,
): void {
  const incomingRequestId = req.header('x-request-id');
  const requestId =
    incomingRequestId && incomingRequestId.trim().length > 0
      ? incomingRequestId.trim()
      : randomUUID();

  req.requestId = requestId;
  res.setHeader('x-request-id', requestId);

  const startedAt = Date.now();

  structuredLog('info', 'request.started', {
    requestId,
    method: req.method,
    path: req.originalUrl || req.url,
  });

  res.on('finish', () => {
    structuredLog('info', 'request.completed', {
      requestId,
      method: req.method,
      path: req.originalUrl || req.url,
      statusCode: res.statusCode,
      durationMs: Date.now() - startedAt,
    });
  });

  next();
}
