import { IsIn, IsString, MinLength } from 'class-validator';

export class LoginDto {
  @IsString()
  username!: string;

  @IsString()
  @MinLength(1)
  password!: string;

  @IsIn(['teacher', 'parent'])
  role!: 'teacher' | 'parent';
}
