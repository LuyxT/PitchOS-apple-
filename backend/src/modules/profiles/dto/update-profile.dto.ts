import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsOptional,
  IsString,
} from 'class-validator';

export class UpdateProfileDto {
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
  @IsDateString()
  birthDate?: string;

  @IsOptional()
  @IsString()
  clubMembership?: string;

  @IsOptional()
  @IsBoolean()
  activeStatus?: boolean;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsArray()
  playerGoals?: string[];

  @IsOptional()
  @IsString()
  playerBiography?: string;

  @IsOptional()
  @IsString()
  playerPreferredRole?: string;

  @IsOptional()
  @IsArray()
  trainerLicenses?: string[];

  @IsOptional()
  @IsArray()
  trainerEducation?: string[];

  @IsOptional()
  @IsString()
  trainerPhilosophy?: string;

  @IsOptional()
  @IsArray()
  trainerGoals?: string[];

  @IsOptional()
  @IsString()
  trainerCareerHistory?: string;

  @IsOptional()
  @IsArray()
  physioQualifications?: string[];

  @IsOptional()
  @IsArray()
  managerResponsibilities?: string[];

  @IsOptional()
  @IsString()
  boardFunction?: string;

  @IsOptional()
  @IsArray()
  boardResponsibilities?: string[];
}
