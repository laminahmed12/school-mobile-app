import { Module } from '@nestjs/common';
import { StudentsController } from './students.controller';
import { StudentsService } from './students.service';
import { PrismaService } from '../prisma.service';
import { JwtModule } from '@nestjs/jwt';

@Module({
  imports: [JwtModule.register({ secret: process.env.JWT_SECRET || 'development-only-secret' })],
  controllers: [StudentsController],
  providers: [StudentsService, PrismaService],
})
export class StudentsModule {}
