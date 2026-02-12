import {
  ArgumentsHost,
  BadRequestException,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Response } from 'express';
import { ERROR_CODES } from '../constants/error-codes';
import { ApiError, ApiEnvelope } from '../interfaces/api-envelope.interface';
import { RequestWithContext } from '../interfaces/request-context.interface';
import { structuredLog } from '../logging/structured-log';

@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const request = ctx.getRequest<RequestWithContext>();
    const response = ctx.getResponse<Response>();

    const requestId = request.requestId ?? 'missing';
    const method = request.method;
    const path = request.originalUrl || request.url;

    const mapped = this.mapException(exception);

    structuredLog('error', 'request.failed', {
      requestId,
      method,
      path,
      statusCode: mapped.statusCode,
      errorCode: mapped.error.code,
      errorMessage: mapped.error.message,
      details: mapped.error.details,
      stack: exception instanceof Error ? exception.stack : undefined,
    });

    const body: ApiEnvelope<null> = {
      success: false,
      data: null,
      error: mapped.error,
    };

    response.status(mapped.statusCode).json(body);
  }

  private mapException(exception: unknown): {
    statusCode: number;
    error: ApiError;
  } {
    if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      if (exception.code === 'P2002') {
        return {
          statusCode: HttpStatus.CONFLICT,
          error: {
            code: ERROR_CODES.conflict,
            message: 'Unique constraint conflict.',
            details: exception.meta,
          },
        };
      }

      return {
        statusCode: HttpStatus.BAD_REQUEST,
        error: {
          code: ERROR_CODES.database,
          message: 'Database request error.',
          details: { code: exception.code, meta: exception.meta },
        },
      };
    }

    if (exception instanceof Prisma.PrismaClientValidationError) {
      return {
        statusCode: HttpStatus.BAD_REQUEST,
        error: {
          code: ERROR_CODES.validation,
          message: 'Database validation error.',
        },
      };
    }

    if (exception instanceof HttpException) {
      const statusCode = exception.getStatus();
      const raw = exception.getResponse();

      if (statusCode === HttpStatus.NOT_FOUND) {
        return {
          statusCode,
          error: {
            code: ERROR_CODES.notFound,
            message: 'Route not found',
          },
        };
      }

      if (typeof raw === 'string') {
        return {
          statusCode,
          error: {
            code: this.mapCodeByStatus(statusCode),
            message: raw,
          },
        };
      }

      if (raw && typeof raw === 'object') {
        const payload = raw as {
          code?: string;
          message?: string | string[];
          details?: unknown;
          error?: string;
        };

        if (Array.isArray(payload.message)) {
          return {
            statusCode,
            error: {
              code: payload.code ?? ERROR_CODES.validation,
              message: 'Validation failed.',
              details: payload.details ?? payload.message,
            },
          };
        }

        if (typeof payload.message === 'string') {
          return {
            statusCode,
            error: {
              code: payload.code ?? this.mapCodeByStatus(statusCode),
              message: payload.message,
              details: payload.details,
            },
          };
        }

        if (typeof payload.error === 'string') {
          return {
            statusCode,
            error: {
              code: payload.code ?? this.mapCodeByStatus(statusCode),
              message: payload.error,
              details: payload.details,
            },
          };
        }
      }

      if (exception instanceof BadRequestException) {
        return {
          statusCode,
          error: {
            code: ERROR_CODES.badRequest,
            message: 'Bad request.',
          },
        };
      }

      return {
        statusCode,
        error: {
          code: this.mapCodeByStatus(statusCode),
          message: 'Request failed.',
        },
      };
    }

    return {
      statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
      error: {
        code: ERROR_CODES.internal,
        message: 'Internal server error.',
      },
    };
  }

  private mapCodeByStatus(statusCode: number): string {
    switch (statusCode) {
      case HttpStatus.BAD_REQUEST:
        return ERROR_CODES.badRequest;
      case HttpStatus.UNAUTHORIZED:
        return ERROR_CODES.unauthorized;
      case HttpStatus.FORBIDDEN:
        return ERROR_CODES.forbidden;
      case HttpStatus.NOT_FOUND:
        return ERROR_CODES.notFound;
      case HttpStatus.CONFLICT:
        return ERROR_CODES.conflict;
      default:
        return ERROR_CODES.internal;
    }
  }
}
