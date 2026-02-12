import { ArgumentsHost, Catch, ExceptionFilter, HttpException, HttpStatus, Logger } from '@nestjs/common';
import { Request, Response } from 'express';
import { Prisma } from '@prisma/client';
import { ApiEnvelope } from '../types/api-envelope';

@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const request = ctx.getRequest<Request & { context?: { requestId?: string } }>();
    const response = ctx.getResponse<Response>();

    const requestId = request?.context?.requestId ?? 'unknown';

    let statusCode = HttpStatus.INTERNAL_SERVER_ERROR;
    let code = 'internalError';
    let message = 'Internal server error';
    let details: unknown = null;

    if (exception instanceof HttpException) {
      statusCode = exception.getStatus();
      const payload = exception.getResponse();
      if (typeof payload === 'string') {
        message = payload;
      } else if (payload && typeof payload === 'object') {
        const maybeCode = (payload as Record<string, unknown>).code;
        const maybeMessage = (payload as Record<string, unknown>).message;
        const maybeDetails = (payload as Record<string, unknown>).details;
        if (typeof maybeCode === 'string') code = maybeCode;
        if (typeof maybeMessage === 'string') message = maybeMessage;
        if (Array.isArray(maybeMessage)) message = maybeMessage.join(', ');
        if (maybeDetails !== undefined) details = maybeDetails;
      }
    } else if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      statusCode = HttpStatus.BAD_REQUEST;
      code = 'databaseError';
      message = 'Database request failed';
      details = { prismaCode: exception.code };
    } else if (exception instanceof Error) {
      message = exception.message || message;
    }

    this.logger.error(`[${requestId}] ${request.method} ${request.url} -> ${statusCode} ${code}: ${message}`);

    const envelope: ApiEnvelope<null> = {
      success: false,
      data: null,
      error: {
        code,
        message,
        details,
      },
      meta: {
        requestId,
        timestamp: new Date().toISOString(),
        version: 'v1',
      },
    };

    response.status(statusCode).json(envelope);
  }
}
