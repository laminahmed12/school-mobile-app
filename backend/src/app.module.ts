import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
import { StudentsModule } from './students/students.module';
import { AttendanceModule } from './attendance/attendance.module';
import { GradesModule } from './grades/grades.module';
import { FinanceModule } from './finance/finance.module';
import { SyncModule } from './sync/sync.module';
import { HealthModule } from './health/health.module';
import { PrismaService } from './prisma.service';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    AuthModule,
    StudentsModule,
    AttendanceModule,
    GradesModule,
    FinanceModule,
    SyncModule,
    HealthModule,
  ],
  providers: [PrismaService],
  exports: [PrismaService],
})
export class AppModule {}
