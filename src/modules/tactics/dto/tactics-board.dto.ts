import { TacticsOpponentMode } from '@prisma/client';
import { IsArray, IsEnum, IsOptional, IsString } from 'class-validator';

export class CreateTacticsBoardDto {
  @IsString()
  teamId!: string;

  @IsString()
  name!: string;

  @IsString()
  scenarioName!: string;

  placements!: Record<string, unknown>;

  @IsOptional()
  @IsArray()
  benchPlayerIds?: string[];

  @IsOptional()
  @IsArray()
  excludedPlayerIds?: string[];

  @IsOptional()
  @IsEnum(TacticsOpponentMode)
  opponentMode?: TacticsOpponentMode;

  @IsOptional()
  opponentMarkers?: Record<string, unknown>;

  @IsOptional()
  drawings?: Record<string, unknown>;

  @IsOptional()
  @IsString()
  cloudFileId?: string;
}

export class UpdateTacticsBoardDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsString()
  scenarioName?: string;

  @IsOptional()
  placements?: Record<string, unknown>;

  @IsOptional()
  @IsArray()
  benchPlayerIds?: string[];

  @IsOptional()
  @IsArray()
  excludedPlayerIds?: string[];

  @IsOptional()
  @IsEnum(TacticsOpponentMode)
  opponentMode?: TacticsOpponentMode;

  @IsOptional()
  opponentMarkers?: Record<string, unknown>;

  @IsOptional()
  drawings?: Record<string, unknown>;

  @IsOptional()
  @IsString()
  cloudFileId?: string;
}
