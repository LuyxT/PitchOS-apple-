import { Controller, Get } from '@nestjs/common';

@Controller()
export class AppController {
  @Get('bootstrap')
  bootstrap() {
    console.log('[bootstrap] endpoint called');
    return {
      status: 'ok',
      service: 'pitchinsights-backend',
      version: '1.0.0',
      time: new Date().toISOString(),
    };
  }

  @Get()
  root() {
    return { status: 'ok', service: 'pitchinsights-backend' };
  }

  @Get('health')
  health() {
    return { status: 'ok' };
  }
}
