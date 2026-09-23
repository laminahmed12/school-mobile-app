import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma.service';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  constructor(private readonly prisma: PrismaService, private readonly jwt: JwtService) {}

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findFirst({
      where: {
        username: dto.username,
        status: 'active',
        role: { code: dto.role },
      },
      include: { role: true },
    });

    if (!user || !user.passwordHash || !(await bcrypt.compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const payload = {
      sub: user.id,
      schoolId: user.schoolId,
      role: user.role.code,
    };

    return {
      access_token: await this.jwt.signAsync(payload),
      user: {
        id: user.id,
        name: [user.firstName, user.lastName].filter(Boolean).join(' '),
        role: user.role.code,
        school_id: user.schoolId,
      },
    };
  }
}
