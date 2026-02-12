import { FileType, FileVisibility } from '@prisma/client';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class RegisterUploadDto {
  @IsString()
  teamId!: string;

  @IsString()
  folderPath!: string;

  @IsString()
  name!: string;

  @IsString()
  originalName!: string;

  @IsEnum(FileType)
  type!: FileType;

  @IsString()
  mimeType!: string;

  @IsInt()
  @Min(1)
  sizeBytes!: number;

  @IsOptional()
  @IsString()
  moduleHint?: string;

  @IsOptional()
  @IsArray()
  tags?: string[];

  @IsOptional()
  @IsEnum(FileVisibility)
  visibility?: FileVisibility;
}

export class CompleteUploadDto {
  @IsBoolean()
  success!: boolean;

  @IsOptional()
  @IsString()
  checksum?: string;
}

export class CreateFolderDto {
  @IsString()
  path!: string;

  @IsString()
  name!: string;
}

export class RenameFileDto {
  @IsString()
  name!: string;
}

export class MoveFileDto {
  @IsString()
  folderPath!: string;
}

export class ShareFileDto {
  @IsArray()
  userIds!: string[];
}
