import { TrainingIntensity, TrainingPhaseType, TrainingStatus } from '@prisma/client';
import {
  IsArray,
  IsDateString,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class TrainingExerciseDto {
  @IsString()
  name!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsInt()
  @Min(1)
  durationMinutes!: number;

  @IsEnum(TrainingIntensity)
  intensity!: TrainingIntensity;

  @IsOptional()
  @IsInt()
  @Min(1)
  requiredPlayers?: number;

  @IsOptional()
  materials?: Record<string, number>;
}

export class TrainingPhaseDto {
  @IsEnum(TrainingPhaseType)
  type!: TrainingPhaseType;

  @IsString()
  title!: string;

  @IsInt()
  @Min(1)
  durationMinutes!: number;

  @IsString()
  goal!: string;

  @IsEnum(TrainingIntensity)
  intensity!: TrainingIntensity;

  @IsOptional()
  @IsString()
  description?: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => TrainingExerciseDto)
  exercises!: TrainingExerciseDto[];
}

export class CreateTrainingPlanDto {
  @IsString()
  teamId!: string;

  @IsString()
  title!: string;

  @IsDateString()
  date!: string;

  @IsOptional()
  @IsString()
  location?: string;

  @IsString()
  mainGoal!: string;

  @IsOptional()
  @IsArray()
  secondaryGoals?: string[];

  @IsOptional()
  @IsEnum(TrainingStatus)
  status?: TrainingStatus;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => TrainingPhaseDto)
  phases!: TrainingPhaseDto[];
}

export class UpdateTrainingPlanDto {
  @IsOptional()
  @IsString()
  title?: string;

  @IsOptional()
  @IsDateString()
  date?: string;

  @IsOptional()
  @IsString()
  location?: string;

  @IsOptional()
  @IsString()
  mainGoal?: string;

  @IsOptional()
  @IsArray()
  secondaryGoals?: string[];

  @IsOptional()
  @IsEnum(TrainingStatus)
  status?: TrainingStatus;
}

export class CreateTemplateDto {
  @IsString()
  teamId!: string;

  @IsString()
  name!: string;

  payload!: Record<string, unknown>;
}

export class CreateReportDto {
  plannedTotalMin!: number;
  actualTotalMin!: number;
  attendance!: Record<string, unknown>;
  groupFeedback!: Record<string, unknown>;
  playerNotes!: Record<string, unknown>;
  @IsOptional()
  @IsString()
  summary?: string;
}

export class LinkCalendarDto {
  @IsString()
  teamId!: string;

  @IsString()
  title!: string;

  @IsDateString()
  startAt!: string;

  @IsDateString()
  endAt!: string;

  @IsOptional()
  @IsString()
  playerVisibleGoal?: string;

  @IsOptional()
  playerVisibleDurationMin?: number;
}
