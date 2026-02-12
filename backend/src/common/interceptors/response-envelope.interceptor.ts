import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import {
  ApiEnvelope,
  isApiEnvelope,
} from '../interfaces/api-envelope.interface';

@Injectable()
export class ResponseEnvelopeInterceptor<T> implements NestInterceptor<
  T,
  ApiEnvelope<T>
> {
  intercept(
    _context: ExecutionContext,
    next: CallHandler<T>,
  ): Observable<ApiEnvelope<T>> {
    return next.handle().pipe(
      map((data) => {
        if (isApiEnvelope(data)) {
          return data as ApiEnvelope<T>;
        }

        return {
          success: true,
          data: data ?? null,
          error: null,
        };
      }),
    );
  }
}
