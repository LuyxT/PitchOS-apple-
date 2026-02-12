import { IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateTeamDto {
  @IsOptional()
  @IsString()
  clubId?: string;

  @IsString()
  @MaxLength(120)
  name!: string;

  @IsString()
  @MaxLength(80)
  ageGroup!: string;

  @IsString()
  @MaxLength(120)
  league!: string;
}
