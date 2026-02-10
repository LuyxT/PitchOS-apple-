import { Module } from '@nestjs/common';
import { SquadsModule } from '../squads/squads.module';

@Module({
  imports: [SquadsModule],
  exports: [SquadsModule],
})
export class SquadModule {}
