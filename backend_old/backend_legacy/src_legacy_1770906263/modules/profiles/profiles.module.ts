import { Module } from '@nestjs/common';
import { ProfilesController } from './profiles.controller';
import { ProfileController } from './profile.controller';
import { ProfilesService } from './profiles.service';

@Module({
  controllers: [ProfilesController, ProfileController],
  providers: [ProfilesService],
  exports: [ProfilesService],
})
export class ProfilesModule {}
