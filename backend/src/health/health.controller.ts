import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  get() {
    return { status: 'ok', service: 'school-management-api', time: new Date().toISOString() };
  }
}
