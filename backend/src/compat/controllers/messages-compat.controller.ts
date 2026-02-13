import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { CompatService } from '../compat.service';

@Controller('messages')
export class MessagesCompatController {
  constructor(private readonly compatService: CompatService) {}

  @Get('threads')
  threads() {
    return this.compatService.emptyArray();
  }

  @Get('chats')
  chats(@Query('cursor') _cursor?: string, @Query('limit') _limit?: string) {
    return this.compatService.messengerChatsPage();
  }

  @Post('chats/direct')
  createDirect(@Body() _body: Record<string, unknown>) {
    return this.compatService.messengerChat();
  }

  @Post('chats/group')
  createGroup(@Body() _body: Record<string, unknown>) {
    return this.compatService.messengerChat();
  }

  @Patch('chats/:chatId')
  updateChat(
    @Param('chatId') chatId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.messengerChat(chatId);
  }

  @Post('chats/:chatId/archive')
  archive(@Param('chatId') chatId: string) {
    return this.compatService.messengerChat(chatId);
  }

  @Post('chats/:chatId/unarchive')
  unarchive(@Param('chatId') chatId: string) {
    return this.compatService.messengerChat(chatId);
  }

  @Get('chats/:chatId/messages')
  messages(
    @Param('chatId') _chatId: string,
    @Query('cursor') _cursor?: string,
    @Query('limit') _limit?: string,
  ) {
    return this.compatService.messengerMessagesPage();
  }

  @Post('chats/:chatId/messages')
  sendMessage(
    @Param('chatId') chatId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.messengerMessage(chatId);
  }

  @Delete('chats/:chatId/messages/:messageId')
  deleteMessage(
    @Param('chatId') _chatId: string,
    @Param('messageId') _messageId: string,
  ) {
    return this.compatService.emptyObject();
  }

  @Post('chats/:chatId/read')
  markRead(
    @Param('chatId') _chatId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.emptyObject();
  }

  @Get('chats/:chatId/read-receipts')
  readReceipts(
    @Param('chatId') _chatId: string,
    @Query('messageId') _messageId?: string,
  ) {
    return this.compatService.emptyArray();
  }

  @Get('search')
  search(@Query('q') _q?: string, @Query('cursor') _cursor?: string) {
    return this.compatService.messengerSearchPage();
  }

  @Post('media/register')
  registerMedia(@Body() _body: Record<string, unknown>) {
    return this.compatService.messengerMediaRegisterResponse();
  }

  @Post('media/:mediaId/complete')
  completeMedia(
    @Param('mediaId') mediaId: string,
    @Body() _body: Record<string, unknown>,
  ) {
    return this.compatService.messengerMediaCompleteResponse(mediaId);
  }

  @Get('media/:mediaId/download')
  mediaDownload(@Param('mediaId') _mediaId: string) {
    return this.compatService.messengerMediaDownloadResponse();
  }
}
