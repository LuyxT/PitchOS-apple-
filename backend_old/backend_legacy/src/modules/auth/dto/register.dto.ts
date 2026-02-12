import { IsEmail, IsEnum, IsOptional, IsString, MinLength } from 'class-validator';
import { RoleType } from '@prisma/client';

export class RegisterDto {
  @IsEmail()
  email!: string;

  @IsString()
  @MinLength(8)
  password!: string;

  @IsString()
  @MinLength(8)
  passwordConfirmation!: string;

  @IsEnum(RoleType)
  role!: RoleType;

  @IsOptional()
  @IsString()
  inviteCode?: string;
}
