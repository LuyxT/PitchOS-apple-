import { IsOptional, IsString, MaxLength } from 'class-validator';

export class CreatePlayerDto {
  @IsString()
  teamId!: string;

  @IsString()
  @MaxLength(120)
  firstName!: string;

  @IsString()
  @MaxLength(120)
  lastName!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  position?: string;
}
