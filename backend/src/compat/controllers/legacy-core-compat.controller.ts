import { Controller, Get } from '@nestjs/common';
import { CompatService } from '../compat.service';

@Controller()
export class LegacyCoreCompatController {
  constructor(private readonly compatService: CompatService) {}

  @Get('trainings')
  trainings() {
    return this.compatService.emptyArray();
  }

  @Get('matches')
  matches() {
    return this.compatService.emptyArray();
  }

  @Get('feedback')
  feedback() {
    return this.compatService.emptyArray();
  }

  @Get('files')
  files() {
    return this.compatService.emptyArray();
  }
}
