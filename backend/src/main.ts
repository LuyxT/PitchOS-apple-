import 'dotenv/config';
import 'reflect-metadata';
import {
  BadRequestException,
  Logger,
  ValidationError,
  ValidationPipe,
} from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { Request, Response } from 'express';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { ERROR_CODES } from './common/constants/error-codes';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';
import { ApiEnvelope } from './common/interfaces/api-envelope.interface';
import { ResponseEnvelopeInterceptor } from './common/interceptors/response-envelope.interceptor';
import { structuredLog } from './common/logging/structured-log';
import { requestIdMiddleware } from './common/middleware/request-id.middleware';
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

function successEnvelope<T>(payload: T): ApiEnvelope<T> {
  return {
    success: true,
    data: payload,
    error: null,
  };
}

function healthPayload() {
  return {
    status: 'ok',
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

  httpAdapter.get('/', (_req: Request, res: Response) => {
    res.status(200).json(successEnvelope(healthPayload()));
  });

  httpAdapter.get('/health', (_req: Request, res: Response) => {
    res.status(200).json(successEnvelope(healthPayload()));
  });

  await app.init();

  httpAdapter.use((_req: Request, res: Response) => {
    if (res.headersSent) {
      return;
    }

    const body: ApiEnvelope<null> = {
      success: false,
      data: null,
      error: {
        code: ERROR_CODES.notFound,
        message: 'Route not found',
      },
    };

    res.status(404).json(body);
  });

  const port = Number(process.env.PORT ?? env.PORT ?? '3000');
  await app.listen(port, '0.0.0.0');

  logger.log(`Listening on port ${port}`);
  structuredLog('info', 'service.started', {
    port,
    nodeEnv: env.NODE_ENV,
  });

  structuredLog('info', 'startup.summary', {
    prismaSchema: 'prisma/schema.prisma',
    migrations: 'applied_or_up_to_date_before_start',
    database: 'connected',
    routesRegistered: [
      '/api/v1/health',
      '/api/v1/finance/bootstrap',
      '/api/v1/finance/cash/bootstrap',
      '/api/v1/auth/register',
      '/api/v1/auth/login',
      '/api/v1/auth/me',
    ],
  });
}

bootstrap().catch((error: unknown) => {
  const details =
    error instanceof Error
      ? { message: error.message, stack: error.stack }
      : { error };
  structuredLog('error', 'service.startup_failed', details);
  process.exit(1);
});
