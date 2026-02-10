import { AnalysisDrawingKind } from '@prisma/client';
import { IsBoolean, IsEnum, IsInt, IsOptional, IsString, Min } from 'class-validator';

export class CreateAnalysisSessionDto {
  @IsString()
  teamId!: string;

  @IsString()
  videoFileId!: string;

  @IsString()
  title!: string;

  @IsOptional()
  @IsString()
  matchId?: string;
}

export class CreateMarkerDto {
  @IsInt()
  @Min(0)
  timeMs!: number;

  @IsOptional()
  @IsString()
  playerId?: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsString()
  comment?: string;
}

export class UpdateMarkerDto {
  @IsOptional()
  @IsInt()
  @Min(0)
  timeMs?: number;

  @IsOptional()
  @IsString()
  playerId?: string;

  @IsOptional()
  @IsString()
  category?: string;

  @IsOptional()
  @IsString()
  comment?: string;
}

export class CreateClipDto {
  @IsString()
  name!: string;

  @IsInt()
  @Min(0)
  startMs!: number;

  @IsInt()
  @Min(1)
  endMs!: number;
}

export class UpdateClipDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  startMs?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  endMs?: number;
}

export class SaveDrawingDto {
  @IsEnum(AnalysisDrawingKind)
  kind!: AnalysisDrawingKind;

  points!: Record<string, unknown>;

  @IsString()
  color!: string;

  @IsOptional()
  @IsBoolean()
  isTemporary?: boolean;
}

export class ShareClipDto {
  playerIds!: string[];
  @IsOptional()
  @IsString()
  threadId?: string;
  @IsOptional()
  @IsString()
  comment?: string;
}
