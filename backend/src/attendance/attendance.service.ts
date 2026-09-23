import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { SyncAttendanceDto } from './dto/sync-attendance.dto';

@Injectable()
export class AttendanceService {
  constructor(private readonly prisma: PrismaService) {}

  async sync(dto: SyncAttendanceDto, schoolId: string, userId: string) {
    const student = await this.prisma.student.findFirst({
      where: { id: dto.student_id, schoolId, isActive: true },
    });
    if (!student) throw new BadRequestException('Student does not belong to this school');

    // id is the client idempotency key. Replays return the existing record.
    const existing = await this.prisma.attendance.findUnique({ where: { id: dto.id } });
    if (existing) return { accepted: true, duplicate: true, id: existing.id };

    const row = await this.prisma.attendance.create({
      data: {
        id: dto.id,
        schoolId,
        studentId: dto.student_id,
        attendanceDate: new Date(dto.date),
        present: dto.present,
        note: dto.note,
        recordedBy: userId,
      },
    });

    return { accepted: true, duplicate: false, id: row.id };
  }
}
