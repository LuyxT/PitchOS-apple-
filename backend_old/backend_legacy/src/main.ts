import 'reflect-metadata';
import { Logger, ValidationPipe, VersioningType } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';
import { ResponseEnvelopeInterceptor } from './common/interceptors/response-envelope.interceptor';
import { validateEnv } from './config/env.validation';

async function bootstrap() {
  const env = validateEnv();
  const logger = new Logger('Bootstrap');

  process.on('unhandledRejection', (error) => {
    logger.error('UNHANDLED_REJECTION', error as Error);
  });
  process.on('uncaughtException', (error) => {
    logger.error('UNCAUGHT_EXCEPTION', error as Error);
  });

  const app = await NestFactory.create(AppModule, {
    cors: true,
    bufferLogs: true,
  });

  app.use(helmet());

  const origins = env.CORS_ORIGINS === '*'
    ? true
    : env.CORS_ORIGINS.split(',').map((value) => value.trim()).filter(Boolean);

  app.enableCors({
    origin: origins,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-Id', 'X-Club-Id', 'X-Team-Id'],
    exposedHeaders: ['x-request-id'],
  });

  app.setGlobalPrefix(env.API_PREFIX.replace(/^\//, ''));
  app.enableVersioning({
    type: VersioningType.URI,
    defaultVersion: '1',
    prefix: 'v',
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  app.useGlobalFilters(new GlobalExceptionFilter());
  app.useGlobalInterceptors(new ResponseEnvelopeInterceptor());

  const swaggerConfig = new DocumentBuilder()
    .setTitle('PitchInsights API')
    .setVersion(env.APP_VERSION)
    .addBearerAuth()
    .build();
  const swaggerDocument = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, swaggerDocument);

  const port = Number(process.env.PORT) || 3000;
  await app.listen(port, '0.0.0.0');

  logger.log(`BOOT_OK ${JSON.stringify({ port, env: env.NODE_ENV, hasDbUrl: Boolean(env.DATABASE_URL) })}`);
}

bootstrap();
