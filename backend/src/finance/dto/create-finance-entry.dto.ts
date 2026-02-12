import { FinanceEntryType } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class CreateFinanceEntryDto {
  @IsOptional()
  @IsString()
  clubId?: string;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  amount!: number;

  @IsEnum(FinanceEntryType)
  type!: FinanceEntryType;

  @IsString()
  @MaxLength(180)
  title!: string;

  @IsDateString()
  date!: string;
}
