import { InvitationStatus, PermissionType, RoleType } from '@prisma/client';
import { IsArray, IsBoolean, IsDateString, IsEmail, IsEnum, IsOptional, IsString } from 'class-validator';

export class CreateRoleDto {
  @IsString()
  name!: string;

  @IsEnum(RoleType)
  type!: RoleType;

  @IsArray()
  permissions!: PermissionType[];
}

export class UpdateRoleDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsArray()
  permissions?: PermissionType[];
}

export class CreateInvitationDto {
  @IsEmail()
  email!: string;

  @IsEnum(RoleType)
  roleType!: RoleType;

  @IsOptional()
  @IsString()
  teamId?: string;
}

export class UpdateInvitationDto {
  @IsEnum(InvitationStatus)
  status!: InvitationStatus;
}

export class CreateSeasonDto {
  @IsString()
  name!: string;

  @IsDateString()
  startsAt!: string;

  @IsDateString()
  endsAt!: string;
}

export class UpdateSeasonDto {
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsBoolean()
  isLocked?: boolean;

  @IsOptional()
  @IsBoolean()
  isArchived?: boolean;
}
