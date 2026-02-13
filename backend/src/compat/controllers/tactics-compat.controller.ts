import { Body, Controller, Get, Put } from '@nestjs/common';
import { CompatService } from '../compat.service';

@Controller('tactics')
export class TacticsCompatController {
  constructor(private readonly compatService: CompatService) {}

  @Get()
  tacticsBoards() {
    return this.compatService.emptyArray();
  }

  @Get('state')
  tacticsState() {
    return this.compatService.tacticsState();
  }

  @Put('state')
  saveTacticsState(@Body() _body: Record<string, unknown>) {
    return this.compatService.emptyObject();
  }
}
