import { Controller, Get, VERSION_NEUTRAL, Version } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  @Version(VERSION_NEUTRAL)
  check() {
    return {
      status: 'ok',
      time: new Date().toISOString(),
      service: 'pitchinsights-backend',
    };
  }
}
