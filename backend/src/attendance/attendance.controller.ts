import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtGuard } from '../common/guards/jwt.guard';
import { AttendanceService } from './attendance.service';
import { SyncAttendanceDto } from './dto/sync-attendance.dto';

@Controller('attendance')
@UseGuards(JwtGuard)
export class AttendanceController {
  constructor(private readonly attendance: AttendanceService) {}

  @Post('sync')
  sync(@Body() dto: SyncAttendanceDto, @CurrentUser() user: any) {
    return this.attendance.sync(dto, user.schoolId, user.sub);
  }
}
