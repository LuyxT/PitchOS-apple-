import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { RequestMethod } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api/v1', {
    exclude: [
      { path: '', method: RequestMethod.GET },
      { path: 'health', method: RequestMethod.GET },
    ],
  });

  const port = Number(process.env.PORT || 3000);
  await app.listen(port, '0.0.0.0');
  console.log(`PitchInsights backend listening on port ${port}`);
}

bootstrap();
