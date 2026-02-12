import { Module } from '@nestjs/common';
import { WidgetsController } from './widgets.controller';
import { WidgetsService } from './widgets.service';
import { WidgetsGateway } from './widgets.gateway';

@Module({
  controllers: [WidgetsController],
  providers: [WidgetsService, WidgetsGateway],
  exports: [WidgetsService, WidgetsGateway],
})
export class WidgetsModule {}
