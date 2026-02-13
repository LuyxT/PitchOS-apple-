import { Module } from '@nestjs/common';
import { CompatService } from './compat.service';
import { AdminCompatController } from './controllers/admin-compat.controller';
import { AnalysisCompatController } from './controllers/analysis-compat.controller';
import { BootstrapCompatController } from './controllers/bootstrap-compat.controller';
import { CalendarCompatController } from './controllers/calendar-compat.controller';
import { CloudCompatController } from './controllers/cloud-compat.controller';
import { LegacyCoreCompatController } from './controllers/legacy-core-compat.controller';
import { MessagesCompatController } from './controllers/messages-compat.controller';
import { PlayersCompatController } from './controllers/players-compat.controller';
import { ProfileCompatController } from './controllers/profile-compat.controller';
import { SettingsCompatController } from './controllers/settings-compat.controller';
import { TacticsCompatController } from './controllers/tactics-compat.controller';
import { TrainingCompatController } from './controllers/training-compat.controller';

@Module({
  controllers: [
    BootstrapCompatController,
    ProfileCompatController,
    CalendarCompatController,
    LegacyCoreCompatController,
    TacticsCompatController,
    AnalysisCompatController,
    TrainingCompatController,
    MessagesCompatController,
    CloudCompatController,
    AdminCompatController,
    SettingsCompatController,
    PlayersCompatController,
  ],
  providers: [CompatService],
})
export class CompatModule {}
