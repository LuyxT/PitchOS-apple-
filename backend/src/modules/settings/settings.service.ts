import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import { SubmitFeedbackDto, UpdateSettingsDto } from './dto/settings.dto';

@Injectable()
export class SettingsService {
  constructor(private readonly prisma: PrismaService) {}

  async get(currentUser: JwtPayload) {
    return this.prisma.userSettings.upsert({
      where: { userId: currentUser.sub },
      create: { userId: currentUser.sub },
      update: {},
    });
  }

  async update(currentUser: JwtPayload, input: UpdateSettingsDto) {
    return this.prisma.userSettings.upsert({
      where: { userId: currentUser.sub },
      create: {
        userId: currentUser.sub,
        language: input.language,
        region: input.region,
        timezone: input.timezone,
        unitSystem: input.unitSystem,
        themeMode: input.themeMode,
        highContrast: input.highContrast,
        uiScale: input.uiScale,
        reduceAnimations: input.reduceAnimations,
        interactivePreviews: input.interactivePreviews,
        notificationsEnabled: input.notificationsEnabled,
        moduleNotifications: input.moduleNotifications as Prisma.InputJsonValue | undefined,
      },
      update: {
        language: input.language,
        region: input.region,
        timezone: input.timezone,
        unitSystem: input.unitSystem,
        themeMode: input.themeMode,
        highContrast: input.highContrast,
        uiScale: input.uiScale,
        reduceAnimations: input.reduceAnimations,
        interactivePreviews: input.interactivePreviews,
        notificationsEnabled: input.notificationsEnabled,
        moduleNotifications: input.moduleNotifications as Prisma.InputJsonValue | undefined,
      },
    });
  }

  async activeSessions(currentUser: JwtPayload) {
    return this.prisma.refreshToken.findMany({
      where: {
        userId: currentUser.sub,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async logoutAll(currentUser: JwtPayload) {
    await this.prisma.refreshToken.updateMany({
      where: { userId: currentUser.sub, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { success: true };
  }

  async submitFeedback(currentUser: JwtPayload, input: SubmitFeedbackDto) {
    return this.prisma.auditLog.create({
      data: {
        organizationId: currentUser.orgId,
        actorUserId: currentUser.sub,
        area: 'settings.feedback',
        action: 'submit',
        targetType: 'feedback',
        targetId: currentUser.sub,
        payload: {
          category: input.category,
          text: input.text,
          screenshotFileId: input.screenshotFileId,
          context: input.context,
        } as Prisma.InputJsonValue,
      },
    });
  }

  async appInfo() {
    return {
      appVersion: '1.0.0',
      buildNumber: '1',
      updatedAt: new Date().toISOString(),
      updateStatus: 'current',
      changelog: [
        'Initial backend release',
        'Core API modules enabled',
      ],
    };
  }
}
