import { Injectable, Logger, NestMiddleware } from '@nestjs/common';
import { NextFunction, Response } from 'express';
import { randomUUID } from 'crypto';
import { RequestWithContext } from '../types/request-context';

@Injectable()
export class RequestIdMiddleware implements NestMiddleware {
  private readonly logger = new Logger(RequestIdMiddleware.name);

  use(req: RequestWithContext, res: Response, next: NextFunction): void {
    const requestId = req.header('x-request-id') || randomUUID();
    req.context = { requestId };
    res.setHeader('x-request-id', requestId);

    const started = Date.now();
    this.logger.log(`[${requestId}] -> ${req.method} ${req.originalUrl}`);
    res.on('finish', () => {
      const duration = Date.now() - started;
      this.logger.log(`[${requestId}] <- ${res.statusCode} ${req.method} ${req.originalUrl} ${duration}ms`);
    });

    next();
  }
}
