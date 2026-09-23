import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { PrismaService } from '../prisma.service';

@Module({
  imports: [JwtModule.register({
    secret: process.env.JWT_SECRET || 'development-only-secret',
    signOptions: { expiresIn: '15m' },
  })],
  controllers: [AuthController],
  providers: [AuthService, PrismaService],
  exports: [JwtModule, AuthService],
})
export class AuthModule {}
