import { IsOptional, IsString, MinLength } from 'class-validator';

export class CreateTeamDto {
  @IsString()
  clubId!: string;

  @IsString()
  @MinLength(2)
  teamName!: string;

  @IsOptional()
  @IsString()
  league?: string;
}
