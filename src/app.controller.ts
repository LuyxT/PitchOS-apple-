import { Controller, Get } from '@nestjs/common';

@Controller()
export class AppController {
  @Get()
  root() {
    return { status: 'ok', service: 'pitchinsights-backend' };
  }

  @Get('health')
  health() {
    return { status: 'ok' };
  }
}
