import { IsArray, IsBoolean, IsOptional, IsString } from 'class-validator';

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  firstName?: string;

  @IsOptional()
  @IsString()
  lastName?: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;

  @IsOptional()
  @IsString()
  primaryTeamId?: string;

  @IsOptional()
  @IsArray()
  roleIds?: string[];

  @IsOptional()
  @IsArray()
  membershipTeamIds?: string[];
}
