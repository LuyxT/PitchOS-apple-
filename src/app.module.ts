import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { validateEnv } from './config/env.validation';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { ProfilesModule } from './modules/profiles/profiles.module';
import { SquadModule } from './modules/squad/squad.module';
import { CalendarModule } from './modules/calendar/calendar.module';
import { TrainingModule } from './modules/training/training.module';
import { TacticsModule } from './modules/tactics/tactics.module';
import { AnalysisModule } from './modules/analysis/analysis.module';
import { MessengerModule } from './modules/messenger/messenger.module';
import { FilesModule } from './modules/files/files.module';
import { CashbookModule } from './modules/cashbook/cashbook.module';
import { SettingsModule } from './modules/settings/settings.module';
import { WidgetsModule } from './modules/widgets/widgets.module';
import { AdminModule } from './modules/admin/admin.module';
import { HealthModule } from './modules/health/health.module';
import { DashboardModule } from './modules/dashboard/dashboard.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, validate: validateEnv }),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 120 }]),
    PrismaModule,
    HealthModule,
    AuthModule,
    UsersModule,
    ProfilesModule,
    SquadModule,
    CalendarModule,
    TrainingModule,
    TacticsModule,
    AnalysisModule,
    MessengerModule,
    FilesModule,
    CashbookModule,
    SettingsModule,
    WidgetsModule,
    DashboardModule,
    AdminModule,
  ],
})
export class AppModule {}
