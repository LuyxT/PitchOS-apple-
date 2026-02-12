import { IsString, MaxLength } from 'class-validator';

export class CreateClubDto {
  @IsString()
  @MaxLength(120)
  name!: string;

  @IsString()
  @MaxLength(120)
  city!: string;

  @IsString()
  @MaxLength(120)
  region!: string;
}
