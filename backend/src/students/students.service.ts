import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma.service';

@Injectable()
export class StudentsService {
  constructor(private readonly prisma: PrismaService) {}

  async teacherStudents(schoolId: string) {
    const rows = await this.prisma.student.findMany({
      where: { schoolId, isActive: true },
      include: {
        enrollments: {
          where: { isActive: true },
          include: { class: true },
          take: 1,
        },
      },
      orderBy: [{ lastName: 'asc' }, { firstName: 'asc' }],
    });

    return {
      items: rows.map(s => ({
        id: s.id,
        name: [s.firstName, s.middleName, s.lastName].filter(Boolean).join(' '),
        class_name: s.enrollments[0]?.class.name ?? '',
      })),
    };
  }

  async parentChildren(userId: string, schoolId: string) {
    const guardian = await this.prisma.guardian.findFirst({ where: { userId, schoolId } });
    if (!guardian) return { items: [] };

    const links = await this.prisma.studentGuardian.findMany({
      where: { guardianId: guardian.id },
      include: {
        student: {
          include: {
            enrollments: { where: { isActive: true }, include: { class: true }, take: 1 },
          },
        },
      },
    });

    return {
      items: links.map(x => ({
        id: x.student.id,
        name: [x.student.firstName, x.student.middleName, x.student.lastName].filter(Boolean).join(' '),
        class_name: x.student.enrollments[0]?.class.name ?? '',
      })),
    };
  }
}
