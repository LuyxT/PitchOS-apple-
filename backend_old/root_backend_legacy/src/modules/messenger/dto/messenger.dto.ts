import { MessageType, MessengerChatType, MessengerWritePolicy } from '@prisma/client';
import { IsArray, IsEnum, IsOptional, IsString } from 'class-validator';

export class CreateDirectChatDto {
  @IsString()
  teamId!: string;

  @IsString()
  participantId!: string;
}

export class CreateGroupChatDto {
  @IsString()
  teamId!: string;

  @IsString()
  name!: string;

  @IsArray()
  participantIds!: string[];

  @IsOptional()
  @IsEnum(MessengerWritePolicy)
  writePolicy?: MessengerWritePolicy;

  @IsOptional()
  temporaryUntil?: string;
}

export class UpdateChatDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  muted?: boolean;

  @IsOptional()
  pinned?: boolean;

  @IsOptional()
  archived?: boolean;

  @IsOptional()
  @IsEnum(MessengerWritePolicy)
  writePolicy?: MessengerWritePolicy;
}

export class SendMessageDto {
  @IsEnum(MessageType)
  type!: MessageType;

  @IsOptional()
  @IsString()
  text?: string;

  @IsOptional()
  @IsString()
  context?: string;

  @IsOptional()
  @IsString()
  attachmentFileId?: string;

  @IsOptional()
  @IsString()
  clipId?: string;

  @IsOptional()
  @IsString()
  analysisSessionId?: string;
}

export class ReadChatDto {
  @IsOptional()
  @IsString()
  lastReadMessageId?: string;
}
