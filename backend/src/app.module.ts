import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { JwtModule } from '@nestjs/jwt';
import { AppController } from './app.controller';
import { AuthModule } from './auth/auth.module';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { FinanceModule } from './finance/finance.module';
import { OnboardingModule } from './onboarding/onboarding.module';
import { PlayersModule } from './players/players.module';
import { PrismaModule } from './prisma/prisma.module';
import { TeamModule } from './team/team.module';

@Module({
  imports: [
    JwtModule.register({ global: true }),
    PrismaModule,
    AuthModule,
    OnboardingModule,
    TeamModule,
    PlayersModule,
    FinanceModule,
  ],
  controllers: [AppController],
  providers: [
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
  ],
})
export class AppModule {}
