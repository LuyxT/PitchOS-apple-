import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { validateEnv } from './config/env.validation';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { ProfilesModule } from './modules/profiles/profiles.module';
import { SquadsModule } from './modules/squads/squads.module';
import { CalendarModule } from './modules/calendar/calendar.module';
import { TrainingModule } from './modules/training/training.module';
import { TacticsModule } from './modules/tactics/tactics.module';
import { AnalysisModule } from './modules/analysis/analysis.module';
import { MessengerModule } from './modules/messenger/messenger.module';
import { FilesModule } from './modules/files/files.module';
import { CashModule } from './modules/cash/cash.module';
import { SettingsModule } from './modules/settings/settings.module';
import { WidgetsModule } from './modules/widgets/widgets.module';
import { AdminModule } from './modules/admin/admin.module';
import { HealthModule } from './modules/health/health.module';
import { OnboardingModule } from './modules/onboarding/onboarding.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, validate: validateEnv }),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 120 }]),
    PrismaModule,
    HealthModule,
    AuthModule,
    UsersModule,
    ProfilesModule,
    SquadsModule,
    CalendarModule,
    TrainingModule,
    TacticsModule,
    AnalysisModule,
    MessengerModule,
    FilesModule,
    CashModule,
    SettingsModule,
    WidgetsModule,
    AdminModule,
    OnboardingModule,
  ],
})
export class AppModule { }
