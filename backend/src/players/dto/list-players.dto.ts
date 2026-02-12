import { IsString } from 'class-validator';

export class ListPlayersDto {
  @IsString()
  teamId!: string;
}
