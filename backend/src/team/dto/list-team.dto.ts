import { IsOptional, IsString } from 'class-validator';

export class ListTeamDto {
  @IsOptional()
  @IsString()
  clubId?: string;
}
