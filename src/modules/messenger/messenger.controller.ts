import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import {
  CreateDirectChatDto,
  CreateGroupChatDto,
  ReadChatDto,
  SendMessageDto,
  UpdateChatDto,
} from './dto/messenger.dto';
import { MessengerService } from './messenger.service';

@ApiTags('messages')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('messages')
export class MessengerController {
  constructor(private readonly messengerService: MessengerService) {}

  @Get('chats')
  async chats(
    @CurrentUser() user: JwtPayload,
    @Query('archived') archived = 'false',
    @Query('q') q?: string,
    @Query('limit') limit = '40',
    @Query('cursor') cursor?: string,
  ) {
    return this.messengerService.listChats(
      user,
      archived === 'true',
      q,
      Number(limit),
      cursor,
    );
  }

  @Post('chats/direct')
  async createDirect(@CurrentUser() user: JwtPayload, @Body() body: CreateDirectChatDto) {
    return this.messengerService.createDirectChat(user, body);
  }

  @Post('chats/group')
  async createGroup(@CurrentUser() user: JwtPayload, @Body() body: CreateGroupChatDto) {
    return this.messengerService.createGroupChat(user, body);
  }

  @Patch('chats/:chatId')
  async updateChat(
    @CurrentUser() user: JwtPayload,
    @Param('chatId') chatId: string,
    @Body() body: UpdateChatDto,
  ) {
    return this.messengerService.updateChat(user, chatId, body);
  }

  @Get('chats/:chatId/messages')
  async messages(
    @CurrentUser() user: JwtPayload,
    @Param('chatId') chatId: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit = '50',
  ) {
    return this.messengerService.loadMessages(user, chatId, cursor, Number(limit));
  }

  @Post('chats/:chatId/messages')
  async send(
    @CurrentUser() user: JwtPayload,
    @Param('chatId') chatId: string,
    @Body() body: SendMessageDto,
  ) {
    return this.messengerService.sendMessage(user, chatId, body);
  }

  @Post('chats/:chatId/read')
  async read(
    @CurrentUser() user: JwtPayload,
    @Param('chatId') chatId: string,
    @Body() body: ReadChatDto,
  ) {
    return this.messengerService.markRead(user, chatId, body);
  }

  @Get('search')
  async search(
    @CurrentUser() user: JwtPayload,
    @Query('q') q: string,
    @Query('includeArchived') includeArchived = 'false',
  ) {
    return this.messengerService.search(user, q, includeArchived === 'true');
  }
}
