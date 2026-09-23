import { Module } from '@nestjs/common';
import { AttendanceController } from './attendance.controller';
import { AttendanceService } from './attendance.service';
import { PrismaService } from '../prisma.service';
import { JwtModule } from '@nestjs/jwt';

@Module({
  imports: [JwtModule.register({ secret: process.env.JWT_SECRET || 'development-only-secret' })],
  controllers: [AttendanceController],
  providers: [AttendanceService, PrismaService],
})
export class AttendanceModule {}
