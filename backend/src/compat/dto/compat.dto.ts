import { IsInt, IsOptional, IsString, Min } from 'class-validator';

export class PaginationQueryDto {
  @IsOptional()
  @IsString()
  cursor?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  limit?: number;
}

export class IdParamDto {
  @IsString()
  id!: string;
}

export class ChatMessageParamDto {
  @IsString()
  chatId!: string;

  @IsString()
  messageId!: string;
}

export class PlanIdParamDto {
  @IsString()
  planId!: string;
}

export class GroupIdParamDto {
  @IsString()
  groupId!: string;
}

export class FileIdParamDto {
  @IsString()
  fileId!: string;
}

export class SeasonIdParamDto {
  @IsString()
  seasonId!: string;
}

export class InvitationIdParamDto {
  @IsString()
  invitationId!: string;
}

export class MediaIdParamDto {
  @IsString()
  mediaId!: string;
}
