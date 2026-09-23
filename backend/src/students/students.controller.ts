import { Controller, Get, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtGuard } from '../common/guards/jwt.guard';
import { StudentsService } from './students.service';

@Controller()
@UseGuards(JwtGuard)
export class StudentsController {
  constructor(private readonly students: StudentsService) {}

  @Get('teacher/students')
  teacherStudents(@CurrentUser() user: any) {
    return this.students.teacherStudents(user.schoolId);
  }

  @Get('parent/children')
  parentChildren(@CurrentUser() user: any) {
    return this.students.parentChildren(user.sub, user.schoolId);
  }
}
