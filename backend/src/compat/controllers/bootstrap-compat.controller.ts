import { Controller, Get } from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { CompatService } from '../compat.service';

@Controller()
export class BootstrapCompatController {
  constructor(private readonly compatService: CompatService) {}

  @Public()
  @Get('bootstrap')
  bootstrap() {
    return this.compatService.bootstrapPayload();
  }
}
