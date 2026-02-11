import 'reflect-metadata';
import { Logger, RequestMethod, ValidationPipe, VersioningType } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import helmet from 'helmet';
import cookieParser from 'cookie-parser';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { RequestIdInterceptor } from './common/interceptors/request-id.interceptor';
import { PrismaService } from './prisma/prisma.service';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { cors: true });
  const logger = new Logger('Bootstrap');

  process.on('unhandledRejection', (reason) => {
    logger.error('Unhandled rejection', reason as Error);
  });
  process.on('uncaughtException', (error) => {
    logger.error('Uncaught exception', error);
  });

  app.use(helmet());
  app.use(cookieParser());
  app.enableCors({ origin: '*' });
  app.enableVersioning({ type: VersioningType.URI, defaultVersion: '1' });
  app.setGlobalPrefix(process.env.API_PREFIX ?? 'api', {
    exclude: [{ path: 'health', method: RequestMethod.GET }],
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );
  app.useGlobalFilters(new HttpExceptionFilter());
  app.useGlobalInterceptors(new RequestIdInterceptor());

  const config = new DocumentBuilder()
    .setTitle('PitchInsights API')
    .setDescription('PitchInsights backend API')
    .setVersion('1.0.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, document);

  if (!process.env.DATABASE_URL) {
    logger.error('DATABASE_URL is missing');
    throw new Error('DATABASE_URL is missing');
  }

  const prisma = app.get(PrismaService);
  try {
    await prisma.$connect();
    logger.log('Database connection established');
  } catch (error) {
    logger.error('Database connection failed', error as Error);
    throw error;
  }

  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port, '0.0.0.0');
  logger.log(`Server running on :${port}`);
}

bootstrap();
