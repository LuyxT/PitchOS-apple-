import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import {
  CreateAnalysisSessionDto,
  CreateClipDto,
  CreateMarkerDto,
  SaveDrawingDto,
  ShareClipDto,
  UpdateClipDto,
  UpdateMarkerDto,
} from './dto/analysis.dto';

@Injectable()
export class AnalysisService {
  constructor(private readonly prisma: PrismaService) {}

  async listSessions(currentUser: JwtPayload, teamId?: string) {
    return this.prisma.analysisSession.findMany({
      where: { teamId: teamId ? teamId : { in: currentUser.teamIds } },
      include: { markers: true, clips: true, drawings: true },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async getSession(currentUser: JwtPayload, id: string) {
    const session = await this.prisma.analysisSession.findUnique({
      where: { id },
      include: { markers: true, clips: true, drawings: true },
    });
    if (!session || !currentUser.teamIds.includes(session.teamId)) {
      throw new NotFoundException('Analysis session not found');
    }
    return session;
  }

  async createSession(currentUser: JwtPayload, input: CreateAnalysisSessionDto) {
    return this.prisma.analysisSession.create({
      data: {
        teamId: input.teamId,
        videoFileId: input.videoFileId,
        title: input.title,
        matchId: input.matchId,
        createdBy: currentUser.sub,
      },
    });
  }

  async createMarker(currentUser: JwtPayload, sessionId: string, input: CreateMarkerDto) {
    await this.getSession(currentUser, sessionId);
    return this.prisma.analysisMarker.create({
      data: {
        sessionId,
        timeMs: input.timeMs,
        playerId: input.playerId,
        category: input.category,
        comment: input.comment,
        createdBy: currentUser.sub,
      },
    });
  }

  async updateMarker(currentUser: JwtPayload, markerId: string, input: UpdateMarkerDto) {
    const marker = await this.prisma.analysisMarker.findUnique({ where: { id: markerId } });
    if (!marker) {
      throw new NotFoundException('Marker not found');
    }
    await this.getSession(currentUser, marker.sessionId);

    return this.prisma.analysisMarker.update({
      where: { id: markerId },
      data: {
        timeMs: input.timeMs,
        playerId: input.playerId,
        category: input.category,
        comment: input.comment,
      },
    });
  }

  async deleteMarker(currentUser: JwtPayload, markerId: string) {
    const marker = await this.prisma.analysisMarker.findUnique({ where: { id: markerId } });
    if (!marker) {
      throw new NotFoundException('Marker not found');
    }
    await this.getSession(currentUser, marker.sessionId);
    await this.prisma.analysisMarker.delete({ where: { id: markerId } });
    return { success: true };
  }

  async createClip(currentUser: JwtPayload, sessionId: string, input: CreateClipDto) {
    const session = await this.getSession(currentUser, sessionId);
    return this.prisma.analysisClip.create({
      data: {
        sessionId,
        videoFileId: session.videoFileId,
        name: input.name,
        startMs: input.startMs,
        endMs: input.endMs,
        createdBy: currentUser.sub,
      },
    });
  }

  async updateClip(currentUser: JwtPayload, clipId: string, input: UpdateClipDto) {
    const clip = await this.prisma.analysisClip.findUnique({ where: { id: clipId } });
    if (!clip) {
      throw new NotFoundException('Clip not found');
    }
    await this.getSession(currentUser, clip.sessionId);

    return this.prisma.analysisClip.update({
      where: { id: clipId },
      data: {
        name: input.name,
        startMs: input.startMs,
        endMs: input.endMs,
      },
    });
  }

  async deleteClip(currentUser: JwtPayload, clipId: string) {
    const clip = await this.prisma.analysisClip.findUnique({ where: { id: clipId } });
    if (!clip) {
      throw new NotFoundException('Clip not found');
    }
    await this.getSession(currentUser, clip.sessionId);
    await this.prisma.analysisClip.delete({ where: { id: clipId } });
    return { success: true };
  }

  async saveDrawings(currentUser: JwtPayload, sessionId: string, drawings: SaveDrawingDto[]) {
    await this.getSession(currentUser, sessionId);

    await this.prisma.analysisDrawing.deleteMany({ where: { sessionId } });

    if (drawings.length > 0) {
      await this.prisma.analysisDrawing.createMany({
        data: drawings.map((drawing) => ({
          sessionId,
          kind: drawing.kind,
          points: drawing.points as Prisma.InputJsonValue,
          color: drawing.color,
          isTemporary: drawing.isTemporary ?? false,
          createdBy: currentUser.sub,
          expiresAt: drawing.isTemporary ? new Date(Date.now() + 3000) : null,
        })),
      });
    }

    return this.prisma.analysisDrawing.findMany({ where: { sessionId } });
  }

  async shareClip(currentUser: JwtPayload, clipId: string, input: ShareClipDto) {
    const clip = await this.prisma.analysisClip.findUnique({ where: { id: clipId } });
    if (!clip) {
      throw new NotFoundException('Clip not found');
    }

    const session = await this.getSession(currentUser, clip.sessionId);

    const targetChats = input.threadId
      ? [input.threadId]
      : await this.findDirectChatsForPlayers(session.teamId, currentUser.sub, input.playerIds ?? []);

    const createdMessages: string[] = [];
    for (const chatId of targetChats) {
      const message = await this.prisma.messengerMessage.create({
        data: {
          chatId,
          senderId: currentUser.sub,
          type: 'ANALYSIS_CLIP_REFERENCE',
          text: input.comment,
          clipId: clip.id,
          analysisSessionId: session.id,
          status: 'SENT',
        },
      });
      createdMessages.push(message.id);
    }

    return { clipId, createdMessageIds: createdMessages };
  }

  private async findDirectChatsForPlayers(teamId: string, senderId: string, playerIds: string[]) {
    if (playerIds.length === 0) {
      return [];
    }

    const members = await this.prisma.player.findMany({
      where: { teamId, id: { in: playerIds } },
      select: { userId: true },
    });

    const targetUserIds = members.map((member) => member.userId).filter((id): id is string => Boolean(id));

    const chats = await this.prisma.messengerChat.findMany({
      where: {
        type: 'DIRECT',
        teamId,
        members: {
          some: { userId: senderId },
        },
      },
      include: { members: true },
    });

    return chats
      .filter((chat) =>
        targetUserIds.some((targetId) => chat.members.some((member) => member.userId === targetId)),
      )
      .map((chat) => chat.id);
  }
}
