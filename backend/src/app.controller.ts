import { Controller, Get, VERSION_NEUTRAL, Version } from '@nestjs/common';

@Controller()
export class AppController {
  @Get()
  @Version(VERSION_NEUTRAL)
  root() {
    return {
      status: 'ok',
      service: 'pitchinsights-backend',
      version: '1.0.0',
      time: new Date().toISOString(),
    };
  }

  @Get('bootstrap')
  @Version(VERSION_NEUTRAL)
  bootstrap() {
    console.log('[bootstrap] endpoint called');
    return {
      status: 'ok',
      service: 'pitchinsights-backend',
      version: '1.0.0',
      time: new Date().toISOString(),
    };
  }
}
