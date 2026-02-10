import {
  CallHandler,
  ExecutionContext,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Request, Response } from 'express';
import { Observable, tap } from 'rxjs';

@Injectable()
export class RequestIdInterceptor implements NestInterceptor {
  private readonly logger = new Logger(RequestIdInterceptor.name);

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context
      .switchToHttp()
      .getRequest<Request & { requestId?: string; method?: string; url?: string }>();
    const response = context.switchToHttp().getResponse<Response & { setHeader: (name: string, value: string) => void; statusCode?: number }>();

    const requestId = request.requestId ?? randomUUID();
    request.requestId = requestId;
    response.setHeader('x-request-id', requestId);

    const startedAt = Date.now();

    return next.handle().pipe(
      tap(() => {
        const duration = Date.now() - startedAt;
        this.logger.log(`${request.method} ${request.url} -> ${response.statusCode} [${duration}ms] (${requestId})`);
      }),
    );
  }
}
