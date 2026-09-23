import { Module } from '@nestjs/common';
import { SyncController } from './sync.controller';
import { PrismaService } from '../prisma.service';

@Module({
  controllers: [SyncController],
  providers: [PrismaService],
})
export class SyncModule {}
