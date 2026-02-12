import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PrismaModule } from './prisma/prisma.module';
import { HealthModule } from './modules/health/health.module';
import { AppController } from './app.controller';
import { OnboardingJwtGuard } from './common/guards/onboarding-jwt.guard';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    JwtModule.register({
      global: true,
      secret: process.env.JWT_SECRET || 'pitchinsights-dev-secret',
      signOptions: { expiresIn: '15m' },
    }),
    PrismaModule,
    HealthModule,
  ],
  controllers: [AppController],
  providers: [OnboardingJwtGuard],
})
export class AppModule { }
