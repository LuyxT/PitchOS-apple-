import { IsIn, IsOptional, IsString } from 'class-validator';

export class JoinClubDto {
  @IsString()
  clubId!: string;

  @IsString()
  @IsIn(['trainer', 'co_trainer', 'physio', 'vorstand', 'player'])
  role!: string;

  @IsOptional()
  @IsString()
  teamId?: string;
}
