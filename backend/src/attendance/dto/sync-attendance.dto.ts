import { IsBoolean, IsISO8601, IsOptional, IsString, IsUUID } from 'class-validator';

export class SyncAttendanceDto {
  @IsUUID()
  id!: string;

  @IsUUID()
  student_id!: string;

  @IsISO8601()
  date!: string;

  @IsBoolean()
  present!: boolean;

  @IsOptional()
  @IsString()
  note?: string;
}
