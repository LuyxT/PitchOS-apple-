import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request & { requestId?: string }>();

    const isHttpException = exception instanceof HttpException;
    const errorResponse = isHttpException
      ? exception.getResponse()
      : { message: 'Internal server error' };
    const message =
      typeof errorResponse === 'string'
        ? errorResponse
        : Array.isArray((errorResponse as any)?.message)
          ? (errorResponse as any).message.join(' ')
          : String((errorResponse as any)?.message ?? 'Unbekannter Fehler');

    this.logger.error({
      path: request.path,
      method: request.method,
      requestId: request.requestId,
      status: 400,
      error: errorResponse,
    });

    response.status(400).json({
      success: false,
      message,
    });
  }
}
