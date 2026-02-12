import { SettingsThemeMode } from '@prisma/client';
import {
  IsBoolean,
  IsEnum,
  IsOptional,
  IsString,
} from 'class-validator';

export class UpdateSettingsDto {
  @IsOptional()
  @IsString()
  language?: string;

  @IsOptional()
  @IsString()
  region?: string;

  @IsOptional()
  @IsString()
  timezone?: string;

  @IsOptional()
  @IsString()
  unitSystem?: string;

  @IsOptional()
  @IsEnum(SettingsThemeMode)
  themeMode?: SettingsThemeMode;

  @IsOptional()
  @IsBoolean()
  highContrast?: boolean;

  @IsOptional()
  @IsString()
  uiScale?: string;

  @IsOptional()
  @IsBoolean()
  reduceAnimations?: boolean;

  @IsOptional()
  @IsBoolean()
  interactivePreviews?: boolean;

  @IsOptional()
  @IsBoolean()
  notificationsEnabled?: boolean;

  @IsOptional()
  moduleNotifications?: Record<string, unknown>;
}

export class SubmitFeedbackDto {
  @IsString()
  category!: string;

  @IsString()
  text!: string;

  @IsOptional()
  @IsString()
  screenshotFileId?: string;

  @IsOptional()
  context?: Record<string, unknown>;
}
