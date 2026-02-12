import { IsOptional, IsString } from 'class-validator';

export class ListFinanceEntriesDto {
  @IsOptional()
  @IsString()
  clubId?: string;
}
