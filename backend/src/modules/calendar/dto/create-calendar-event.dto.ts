import { CalendarEventKind, CalendarVisibility } from '@prisma/client';
import {
  IsDateString,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class CreateCalendarEventDto {
  @IsString()
  teamId!: string;

  @IsString()
  @MaxLength(120)
  title!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsDateString()
  startAt!: string;

  @IsDateString()
  endAt!: string;

  @IsOptional()
  @IsEnum(CalendarVisibility)
  visibility?: CalendarVisibility;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsEnum(CalendarEventKind)
  eventKind?: CalendarEventKind;

  @IsOptional()
  @IsString()
  linkedTrainingPlanId?: string;

  @IsOptional()
  @IsString()
  playerVisibleGoal?: string;

  @IsOptional()
  playerVisibleDurationMin?: number;
}
