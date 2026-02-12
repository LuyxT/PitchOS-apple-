import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { map, Observable } from 'rxjs';
import { ApiEnvelope } from '../types/api-envelope';
import { RequestWithContext } from '../types/request-context';

@Injectable()
export class ResponseEnvelopeInterceptor<T> implements NestInterceptor<T, ApiEnvelope<T>> {
  intercept(context: ExecutionContext, next: CallHandler): Observable<ApiEnvelope<T>> {
    const request = context.switchToHttp().getRequest<RequestWithContext>();
    const requestId = request?.context?.requestId ?? 'unknown';

    return next.handle().pipe(
      map((data: T) => ({
        success: true,
        data: data ?? null,
        error: null,
        meta: {
          requestId,
          timestamp: new Date().toISOString(),
          version: 'v1' as const,
        },
      })),
    );
  }
}
