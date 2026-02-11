import 'reflect-metadata';
import { Logger, RequestMethod, ValidationPipe, VersioningType } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import helmet from 'helmet';
import cookieParser from 'cookie-parser';
import { existsSync } from 'fs';
import { join } from 'path';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { RequestIdInterceptor } from './common/interceptors/request-id.interceptor';
import { PrismaService } from './prisma/prisma.service';

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  process.on('unhandledRejection', (error) => {
    console.error('UNHANDLED_REJECTION', error);
  });
  process.on('uncaughtException', (error) => {
    console.error('UNCAUGHT_EXCEPTION', error);
  });

  try {
    const app = await NestFactory.create(AppModule, { cors: true });

    app.use(helmet());
    app.use(cookieParser());
    app.enableCors({ origin: '*' });
    app.enableVersioning({ type: VersioningType.URI, defaultVersion: '1' });
    app.setGlobalPrefix(process.env.API_PREFIX ?? 'api', {
      exclude: [
        { path: '', method: RequestMethod.GET },
        { path: 'bootstrap', method: RequestMethod.GET },
        { path: 'health', method: RequestMethod.GET },
      ],
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

    const schemaPath = join(process.cwd(), 'prisma', 'schema.prisma');
    logger.log(`Prisma schema path: ${schemaPath} (exists: ${existsSync(schemaPath)})`);

    const port = Number(process.env.PORT || 3000);
    await app.listen(port, '0.0.0.0');
    console.log('BOOT_OK', {
      port,
      env: process.env.NODE_ENV ?? 'development',
      hasDbUrl: Boolean(process.env.DATABASE_URL),
    });

    const prisma = app.get(PrismaService);
    try {
      if (!process.env.DATABASE_URL) {
        logger.error('DATABASE_URL missing - running in degraded mode');
      } else if (!prisma.isConnected()) {
        await prisma.$connect();
      }
    } catch (error) {
      logger.error('Database initialization failed - running in degraded mode', error as Error);
    }
  } catch (error) {
    logger.error('Bootstrap failed', error as Error);
  }
}

bootstrap();
