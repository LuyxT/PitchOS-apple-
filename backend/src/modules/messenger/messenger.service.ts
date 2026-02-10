import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import {
  CreateDirectChatDto,
  CreateGroupChatDto,
  ReadChatDto,
  SendMessageDto,
  UpdateChatDto,
} from './dto/messenger.dto';
import { MessengerGateway } from './messenger.gateway';

@Injectable()
export class MessengerService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly gateway: MessengerGateway,
  ) {}

  async listChats(currentUser: JwtPayload, archived = false, q?: string, limit = 40, cursor?: string) {
    const memberships = await this.prisma.messengerChatMember.findMany({
      where: { userId: currentUser.sub },
      include: {
        chat: {
          include: {
            messages: {
              take: 1,
              orderBy: { createdAt: 'desc' },
            },
          },
        },
      },
      orderBy: { joinedAt: 'desc' },
      take: Math.min(Math.max(limit, 1), 100),
      skip: cursor ? 1 : 0,
      cursor: cursor ? { id: cursor } : undefined,
    });

    const filtered = memberships.filter((membership) => {
      if (membership.chat.isArchived !== archived) {
        return false;
      }
      if (!q) {
        return true;
      }
      const latest = membership.chat.messages[0]?.text ?? '';
      const name = membership.chat.name ?? '';
      const query = q.toLowerCase();
      return name.toLowerCase().includes(query) || latest.toLowerCase().includes(query);
    });

    return {
      data: filtered,
      nextCursor: memberships.length === limit ? memberships[memberships.length - 1].id : null,
    };
  }

  async createDirectChat(currentUser: JwtPayload, input: CreateDirectChatDto) {
    const existing = await this.prisma.messengerChat.findFirst({
      where: {
        teamId: input.teamId,
        type: 'DIRECT',
        members: {
          every: { userId: { in: [currentUser.sub, input.participantId] } },
        },
      },
      include: { members: true },
    });

    if (existing && existing.members.length === 2) {
      return existing;
    }

    return this.prisma.messengerChat.create({
      data: {
        teamId: input.teamId,
        type: 'DIRECT',
        createdBy: currentUser.sub,
        members: {
          createMany: {
            data: [{ userId: currentUser.sub }, { userId: input.participantId }],
          },
        },
      },
      include: { members: true },
    });
  }

  async createGroupChat(currentUser: JwtPayload, input: CreateGroupChatDto) {
    const participantIds = Array.from(new Set([currentUser.sub, ...input.participantIds]));

    return this.prisma.messengerChat.create({
      data: {
        teamId: input.teamId,
        type: 'GROUP',
        name: input.name,
        writePolicy: input.writePolicy,
        temporaryUntil: input.temporaryUntil ? new Date(input.temporaryUntil) : undefined,
        createdBy: currentUser.sub,
        members: {
          createMany: {
            data: participantIds.map((userId) => ({ userId })),
            skipDuplicates: true,
          },
        },
      },
      include: { members: true },
    });
  }

  async updateChat(currentUser: JwtPayload, chatId: string, input: UpdateChatDto) {
    await this.ensureMembership(currentUser.sub, chatId);

    if (input.muted !== undefined || input.pinned !== undefined) {
      await this.prisma.messengerChatMember.updateMany({
        where: { chatId, userId: currentUser.sub },
        data: {
          muted: input.muted,
          pinned: input.pinned,
        },
      });
    }

    if (
      input.name !== undefined ||
      input.archived !== undefined ||
      input.writePolicy !== undefined
    ) {
      await this.prisma.messengerChat.update({
        where: { id: chatId },
        data: {
          name: input.name,
          isArchived: input.archived,
          writePolicy: input.writePolicy,
        },
      });
    }

    const chat = await this.prisma.messengerChat.findUniqueOrThrow({
      where: { id: chatId },
      include: { members: true },
    });

    this.gateway.publishToChat(chatId, 'chat.updated', chat);
    return chat;
  }

  async loadMessages(currentUser: JwtPayload, chatId: string, cursor?: string, limit = 50) {
    await this.ensureMembership(currentUser.sub, chatId);

    const messages = await this.prisma.messengerMessage.findMany({
      where: { chatId },
      orderBy: { createdAt: 'desc' },
      take: Math.min(Math.max(limit, 1), 100),
      skip: cursor ? 1 : 0,
      cursor: cursor ? { id: cursor } : undefined,
      include: { receipts: true },
    });

    return {
      data: messages,
      nextCursor: messages.length === limit ? messages[messages.length - 1].id : null,
    };
  }

  async sendMessage(currentUser: JwtPayload, chatId: string, input: SendMessageDto) {
    await this.ensureMembership(currentUser.sub, chatId);

    const message = await this.prisma.messengerMessage.create({
      data: {
        chatId,
        senderId: currentUser.sub,
        type: input.type,
        text: input.text,
        context: input.context,
        attachmentFileId: input.attachmentFileId,
        clipId: input.clipId,
        analysisSessionId: input.analysisSessionId,
        status: 'SENT',
      },
      include: { receipts: true },
    });

    await this.prisma.messengerChat.update({
      where: { id: chatId },
      data: { updatedAt: new Date() },
    });

    await this.prisma.messengerChatMember.updateMany({
      where: { chatId, userId: { not: currentUser.sub } },
      data: {
        unreadCount: { increment: 1 },
      },
    });

    this.gateway.publishToChat(chatId, 'message.created', message);
    return message;
  }

  async markRead(currentUser: JwtPayload, chatId: string, input: ReadChatDto) {
    await this.ensureMembership(currentUser.sub, chatId);

    await this.prisma.messengerChatMember.updateMany({
      where: { chatId, userId: currentUser.sub },
      data: {
        unreadCount: 0,
        lastReadMessageId: input.lastReadMessageId,
      },
    });

    if (input.lastReadMessageId) {
      await this.prisma.messengerReadReceipt.upsert({
        where: {
          messageId_userId: {
            messageId: input.lastReadMessageId,
            userId: currentUser.sub,
          },
        },
        create: {
          messageId: input.lastReadMessageId,
          userId: currentUser.sub,
        },
        update: {
          readAt: new Date(),
        },
      });
    }

    this.gateway.publishToChat(chatId, 'receipt.updated', {
      chatId,
      userId: currentUser.sub,
      messageId: input.lastReadMessageId,
      readAt: new Date().toISOString(),
    });

    return { success: true };
  }

  async search(currentUser: JwtPayload, q: string, includeArchived = false) {
    const memberships = await this.prisma.messengerChatMember.findMany({
      where: { userId: currentUser.sub, chat: { isArchived: includeArchived ? undefined : false } },
      select: { chatId: true },
    });
    const chatIds = memberships.map((m) => m.chatId);

    const [chatResults, messageResults, clipResults, markerResults] = await Promise.all([
      this.prisma.messengerChat.findMany({
        where: { id: { in: chatIds }, name: { contains: q, mode: 'insensitive' } },
        take: 30,
      }),
      this.prisma.messengerMessage.findMany({
        where: { chatId: { in: chatIds }, text: { contains: q, mode: 'insensitive' } },
        take: 30,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.analysisClip.findMany({
        where: { name: { contains: q, mode: 'insensitive' } },
        take: 30,
      }),
      this.prisma.analysisMarker.findMany({
        where: { comment: { contains: q, mode: 'insensitive' } },
        take: 30,
      }),
    ]);

    return {
      chats: chatResults,
      messages: messageResults,
      clips: clipResults,
      markers: markerResults,
    };
  }

  private async ensureMembership(userId: string, chatId: string) {
    const member = await this.prisma.messengerChatMember.findFirst({
      where: { userId, chatId },
    });
    if (!member) {
      throw new NotFoundException('Chat not found');
    }
    return member;
  }
}
