import { Controller, Get } from '@nestjs/common';

@Controller()
export class AppController {
  @Get()
  root() {
    return {
      status: 'ok',
      service: 'pitchinsights-backend',
      version: '1.0.0',
      time: new Date().toISOString(),
    };
  }
}
