import { IsArray, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class CreatePlayerDto {
  @IsString()
  userId!: string;

  @IsString()
  teamId!: string;

  @IsString()
  primaryPosition!: string;

  @IsOptional()
  @IsArray()
  secondaryPositions?: string[];

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(99)
  jerseyNumber?: number;

  @IsOptional()
  @IsString()
  fitnessStatus?: string;

  @IsOptional()
  @IsString()
  squadStatus?: string;

  @IsOptional()
  @IsString()
  availabilityStatus?: string;
}
