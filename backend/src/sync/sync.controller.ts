import { Controller, Get } from '@nestjs/common';

@Controller('sync')
export class SyncController {
  @Get('health')
  health() {
    return { ok: true, server_time: new Date().toISOString() };
  }
}
