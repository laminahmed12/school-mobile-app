import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { IsNumber, IsUUID, Max, Min } from 'class-validator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtGuard } from '../common/guards/jwt.guard';
import { PrismaService } from '../prisma.service';

class GradeDto {
  @IsUUID() id!: string;
  @IsUUID() student_id!: string;
  @IsUUID() subject_id!: string;
  @IsNumber() @Min(0) @Max(100) score!: number;
}

@Controller('grades')
@UseGuards(JwtGuard)
export class GradesController {
  constructor(private readonly prisma: PrismaService) {}

  @Post()
  async create(@Body() dto: GradeDto, @CurrentUser() user: any) {
    const student = await this.prisma.student.findFirst({
      where: { id: dto.student_id, schoolId: user.schoolId },
    });
    if (!student) throw new Error('Invalid student');

    const row = await this.prisma.gradeEntry.upsert({
      where: { id: dto.id },
      update: { score: dto.score },
      create: {
        id: dto.id,
        schoolId: user.schoolId,
        studentId: dto.student_id,
        subjectId: dto.subject_id,
        score: dto.score,
        recordedBy: user.sub,
      },
    });
    return { accepted: true, id: row.id };
  }
}
