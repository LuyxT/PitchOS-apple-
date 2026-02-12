import 'dotenv/config';
import 'reflect-metadata';
import {
  BadRequestException,
  Logger,
  ValidationError,
  ValidationPipe,
} from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { ERROR_CODES } from './common/constants/error-codes';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';
import { ResponseEnvelopeInterceptor } from './common/interceptors/response-envelope.interceptor';
import { structuredLog } from './common/logging/structured-log';
import { requestIdMiddleware } from './common/middleware/request-id.middleware';
import { ApiEnvelope } from './common/interfaces/api-envelope.interface';
import { getCorsOrigins, getEnv } from './config/env';

function formatValidationErrors(errors: ValidationError[]) {
  return errors.map((error) => ({
    field: error.property,
    constraints: error.constraints ?? {},
    children: error.children?.map((child) => ({
      field: child.property,
      constraints: child.constraints ?? {},
    })),
  }));
}

function healthPayload() {
  return {
    status: 'ok',
    timestamp: new Date().toISOString(),
  };
}

async function bootstrap() {
  const env = getEnv();
  const logger = new Logger('Bootstrap');

  process.on('unhandledRejection', (reason) => {
    structuredLog('error', 'process.unhandled_rejection', {
      reason: reason instanceof Error ? reason.message : reason,
    });
  });

  process.on('uncaughtException', (error) => {
    structuredLog('error', 'process.uncaught_exception', {
      message: error.message,
      stack: error.stack,
    });
  });

  structuredLog('info', 'service.starting', {
    nodeEnv: env.NODE_ENV,
  });

  const app = await NestFactory.create(AppModule, {
    bufferLogs: true,
  });

  app.use(requestIdMiddleware);
  app.use(helmet());

  app.enableCors({
    origin: getCorsOrigins(),
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-Id'],
    exposedHeaders: ['x-request-id'],
  });

  app.setGlobalPrefix('api/v1');

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
      transformOptions: { enableImplicitConversion: true },
      exceptionFactory: (validationErrors: ValidationError[]) =>
        new BadRequestException({
          code: ERROR_CODES.validation,
          message: 'Validation failed.',
          details: formatValidationErrors(validationErrors),
        }),
    }),
  );

  app.useGlobalInterceptors(new ResponseEnvelopeInterceptor());
  app.useGlobalFilters(new GlobalExceptionFilter());

  const httpAdapter = app.getHttpAdapter().getInstance();

  httpAdapter.get(
    '/',
    (
      _req: unknown,
      res: {
        status: (code: number) => {
          json: (body: ApiEnvelope<Record<string, unknown>>) => void;
        };
      },
    ) => {
      const body: ApiEnvelope<Record<string, unknown>> = {
        success: true,
        data: healthPayload(),
        error: null,
      };

      res.status(200).json(body);
    },
  );

  httpAdapter.get(
    '/health',
    (
      _req: unknown,
      res: {
        status: (code: number) => {
          json: (body: ApiEnvelope<Record<string, unknown>>) => void;
        };
      },
    ) => {
      const body: ApiEnvelope<Record<string, unknown>> = {
        success: true,
        data: healthPayload(),
        error: null,
      };

      res.status(200).json(body);
    },
  );

  const port = Number(process.env.PORT ?? env.PORT ?? '3000');
  await app.listen(port, '0.0.0.0');

  logger.log(`Listening on port ${port}`);
  structuredLog('info', 'service.started', {
    port,
    nodeEnv: env.NODE_ENV,
  });
}

bootstrap();
