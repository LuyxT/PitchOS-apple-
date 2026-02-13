import { Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';

@Injectable()
export class CompatService {
  private readonly defaultTeamId = 'team-default';

  bootstrapPayload() {
    return {
      status: 'ok',
      service: 'pitchinsights-backend',
      version: '1.0.0',
      time: this.nowIso(),
    };
  }

  coachProfile() {
    return {
      name: '',
      license: '',
      team: '',
      seasonGoal: '',
    };
  }

  personProfile(id?: string) {
    return {
      id: id ?? this.id(),
      linkedPlayerID: null,
      linkedAdminPersonID: null,
      core: {
        avatarPath: null,
        firstName: '',
        lastName: '',
        dateOfBirth: null,
        email: '',
        phone: null,
        clubName: '',
        roles: ['trainer'],
        isActive: true,
        internalNotes: '',
      },
      player: null,
      headCoach: null,
      assistantCoach: null,
      athleticCoach: null,
      medical: null,
      teamManager: null,
      board: null,
      facility: null,
      lockedFieldKeys: [],
      updatedAt: this.nowIso(),
      updatedBy: 'system',
    };
  }

  profileAuditEntry(profileId?: string) {
    return {
      id: this.id(),
      profileID: profileId ?? this.id(),
      actorName: 'System',
      fieldPath: 'core.firstName',
      area: 'core',
      oldValue: '',
      newValue: '',
      timestamp: this.nowIso(),
    };
  }

  calendarCategoryTraining() {
    return {
      id: '11111111-1111-1111-1111-111111111111',
      name: 'Training',
      colorHex: '#22C55E',
      isSystem: true,
    };
  }

  calendarCategoryMatch() {
    return {
      id: '22222222-2222-2222-2222-222222222222',
      name: 'Spiel',
      colorHex: '#3B82F6',
      isSystem: true,
    };
  }

  calendarEvent(id?: string) {
    return {
      id: id ?? this.id(),
      title: 'Neues Event',
      startDate: this.nowIso(),
      endDate: this.nowIso(),
      categoryId: this.calendarCategoryTraining().id,
      visibility: 'team',
      audience: 'team',
      audiencePlayerIds: [],
      recurrence: 'none',
      location: '',
      notes: '',
      linkedTrainingPlanID: null,
      eventKind: 'generic',
      playerVisibleGoal: null,
      playerVisibleDurationMinutes: null,
    };
  }

  player(id?: string) {
    return {
      id: id ?? this.id(),
      name: '',
      number: 0,
      position: '',
      status: 'active',
      dateOfBirth: null,
      secondaryPositions: [],
      heightCm: null,
      weightKg: null,
      preferredFoot: null,
      teamName: null,
      squadStatus: null,
      joinedAt: null,
      roles: [],
      groups: [],
      injuryStatus: null,
      notes: null,
      developmentGoals: null,
    };
  }

  tacticsState() {
    return {
      activeScenarioID: null,
      scenarios: [],
      boards: [],
    };
  }

  tacticBoard() {
    return {
      title: 'Standard',
      detail: '',
    };
  }

  analysisVideoRegisterResponse() {
    return {
      videoID: this.id(),
      uploadURL: 'https://example.com/upload',
      uploadHeaders: {},
      expiresAt: this.nowIso(),
    };
  }

  analysisVideoCompleteResponse(videoId?: string) {
    return {
      videoID: videoId ?? this.id(),
      playbackReady: true,
    };
  }

  signedPlaybackResponse() {
    return {
      signedPlaybackURL: 'https://example.com/playback',
      expiresAt: this.nowIso(),
    };
  }

  analysisSession(id?: string) {
    return {
      id: id ?? this.id(),
      videoID: this.id(),
      title: 'Analyse',
      matchID: null,
      teamID: null,
      createdAt: this.nowIso(),
      updatedAt: this.nowIso(),
    };
  }

  analysisMarker(id?: string, sessionId?: string) {
    return {
      id: id ?? this.id(),
      sessionID: sessionId ?? this.id(),
      videoID: this.id(),
      timeSeconds: 0,
      categoryID: null,
      comment: '',
      playerID: null,
      createdAt: this.nowIso(),
      updatedAt: this.nowIso(),
    };
  }

  analysisClip(id?: string, sessionId?: string) {
    return {
      id: id ?? this.id(),
      sessionID: sessionId ?? this.id(),
      videoID: this.id(),
      name: 'Clip',
      startSeconds: 0,
      endSeconds: 1,
      playerIDs: [],
      note: '',
      createdAt: this.nowIso(),
      updatedAt: this.nowIso(),
    };
  }

  analysisSessionEnvelope(sessionId?: string) {
    return {
      session: this.analysisSession(sessionId),
      markers: [],
      clips: [],
      drawings: [],
    };
  }

  shareClipResponse() {
    return {
      threadID: this.id(),
      messageIDs: [],
    };
  }

  trainingPlan(id?: string) {
    return {
      id: id ?? this.id(),
      title: 'Training',
      date: this.nowIso(),
      location: '',
      mainGoal: '',
      secondaryGoals: [],
      status: 'draft',
      linkedMatchID: null,
      calendarEventID: null,
      createdAt: this.nowIso(),
      updatedAt: this.nowIso(),
    };
  }

  trainingPhase(planId?: string) {
    return {
      id: this.id(),
      planID: planId ?? this.id(),
      orderIndex: 0,
      type: 'phase',
      title: 'Phase',
      durationMinutes: 0,
      goal: '',
      intensity: 'low',
      description: '',
      isCompletedLive: false,
    };
  }

  trainingExercise(phaseId?: string) {
    return {
      id: this.id(),
      phaseID: phaseId ?? this.id(),
      orderIndex: 0,
      name: 'Exercise',
      description: '',
      durationMinutes: 0,
      intensity: 'low',
      requiredPlayers: 0,
      materials: [],
      excludedPlayerIDs: [],
      templateSourceID: null,
      isSkippedLive: false,
      actualDurationMinutes: null,
    };
  }

  trainingTemplate(id?: string) {
    return {
      id: id ?? this.id(),
      name: 'Template',
      baseDescription: '',
      defaultDuration: 0,
      defaultIntensity: 'low',
      defaultRequiredPlayers: 0,
      defaultMaterials: [],
    };
  }

  trainingGroup(planId?: string, groupId?: string) {
    return {
      id: groupId ?? this.id(),
      planID: planId ?? this.id(),
      name: 'Group',
      goal: '',
      playerIDs: [],
      headCoachUserID: 'system',
      assistantCoachUserID: null,
    };
  }

  trainingGroupBriefing(groupId?: string) {
    return {
      id: this.id(),
      groupID: groupId ?? this.id(),
      goal: '',
      coachingPoints: '',
      focusPoints: '',
      commonMistakes: '',
      targetIntensity: 'low',
    };
  }

  trainingAvailabilitySnapshot() {
    return {
      playerID: this.id(),
      availability: 'fit',
      isAbsent: false,
      isLimited: false,
      note: '',
    };
  }

  trainingDeviation(planId?: string) {
    return {
      id: this.id(),
      planID: planId ?? this.id(),
      phaseID: null,
      exerciseID: null,
      kind: 'generic',
      plannedValue: '',
      actualValue: '',
      note: '',
      timestamp: this.nowIso(),
    };
  }

  trainingReport(planId?: string) {
    return {
      id: this.id(),
      planID: planId ?? this.id(),
      generatedAt: this.nowIso(),
      plannedTotalMinutes: 0,
      actualTotalMinutes: 0,
      attendance: [],
      groupFeedback: [],
      playerNotes: [],
      summary: '',
    };
  }

  trainingPlanEnvelope(planId?: string) {
    return {
      plan: this.trainingPlan(planId),
      phases: [],
      exercises: [],
      groups: [],
      briefings: [],
      report: null,
      availability: [],
      deviations: [],
    };
  }

  trainingPlansPage() {
    return {
      items: [],
      nextCursor: null,
    };
  }

  trainingTemplatesPage() {
    return {
      items: [],
      nextCursor: null,
    };
  }

  trainingSession() {
    return {
      title: 'Training',
      date: this.nowIso(),
      focus: '',
    };
  }

  matchInfo() {
    return {
      opponent: '',
      date: this.nowIso(),
      homeAway: 'home',
    };
  }

  messageThread() {
    return {
      title: '',
      lastMessage: '',
      unreadCount: 0,
    };
  }

  messengerParticipant() {
    return {
      userID: this.id(),
      displayName: 'User',
      role: 'STAFF',
      playerID: null,
      mutedUntil: null,
      canWrite: true,
      joinedAt: this.nowIso(),
    };
  }

  messengerChat(chatId?: string) {
    return {
      id: chatId ?? this.id(),
      title: 'Chat',
      type: 'group',
      participants: [],
      lastMessagePreview: null,
      lastMessageAt: null,
      unreadCount: 0,
      pinned: false,
      muted: false,
      archived: false,
      writePermission: 'all',
      temporaryUntil: null,
      createdAt: this.nowIso(),
      updatedAt: this.nowIso(),
    };
  }

  messengerChatsPage() {
    return {
      items: [],
      nextCursor: null,
    };
  }

  messengerReadReceipt() {
    return {
      userID: this.id(),
      userName: 'User',
      readAt: this.nowIso(),
    };
  }

  messengerMessage(chatId?: string, messageId?: string) {
    return {
      id: messageId ?? this.id(),
      chatID: chatId ?? this.id(),
      senderUserID: this.id(),
      senderName: 'User',
      type: 'text',
      text: '',
      contextLabel: null,
      attachment: null,
      clipReference: null,
      createdAt: this.nowIso(),
      updatedAt: this.nowIso(),
      status: 'sent',
      readBy: [],
    };
  }

  messengerMessagesPage() {
    return {
      items: [],
      nextCursor: null,
    };
  }

  messengerSearchPage() {
    return {
      items: [],
      nextCursor: null,
    };
  }

  messengerMediaRegisterResponse() {
    return {
      mediaID: this.id(),
      uploadURL: 'https://example.com/upload',
      uploadHeaders: {},
      expiresAt: this.nowIso(),
    };
  }

  messengerMediaCompleteResponse(mediaId?: string) {
    return {
      mediaID: mediaId ?? this.id(),
      ready: true,
    };
  }

  messengerMediaDownloadResponse() {
    return {
      signedURL: 'https://example.com/download',
      expiresAt: this.nowIso(),
    };
  }

  feedbackEntry() {
    return {
      player: '',
      summary: '',
      date: this.nowIso(),
    };
  }

  fileItem() {
    return {
      name: '',
      category: '',
    };
  }

  cloudUsage(teamId?: string) {
    return {
      teamID: teamId ?? this.defaultTeamId,
      quotaBytes: 5_000_000_000,
      usedBytes: 0,
      updatedAt: this.nowIso(),
    };
  }

  cloudFolder(folderId?: string, teamId?: string) {
    return {
      id: folderId ?? this.id(),
      teamID: teamId ?? this.defaultTeamId,
      parentID: null,
      name: 'Ordner',
      createdAt: this.nowIso(),
      updatedAt: this.nowIso(),
      isSystemFolder: false,
      isDeleted: false,
    };
  }

  cloudFile(fileId?: string, teamId?: string) {
    return {
      id: fileId ?? this.id(),
      teamID: teamId ?? this.defaultTeamId,
      ownerUserID: this.id(),
      name: 'Datei',
      originalName: 'Datei',
      type: 'document',
      mimeType: 'application/octet-stream',
      sizeBytes: 0,
      createdAt: this.nowIso(),
      updatedAt: this.nowIso(),
      folderID: null,
      tags: [],
      moduleHint: null,
      visibility: 'team',
      sharedUserIDs: [],
      checksum: null,
      uploadStatus: 'ready',
      deletedAt: null,
      linkedAnalysisSessionID: null,
      linkedAnalysisClipID: null,
      linkedTacticsScenarioID: null,
      linkedTrainingPlanID: null,
    };
  }

  cloudFilesPage() {
    return {
      items: [],
      nextCursor: null,
    };
  }

  cloudFilesBootstrap(teamId?: string) {
    const resolved = teamId && teamId.length > 0 ? teamId : this.defaultTeamId;
    return {
      teamID: resolved,
      usage: this.cloudUsage(resolved),
      folders: [],
      files: [],
      nextCursor: null,
    };
  }

  cloudRegisterUploadResponse() {
    return {
      fileID: this.id(),
      uploadID: this.id(),
      uploadURL: 'https://example.com/upload',
      uploadHeaders: {},
      chunkSizeBytes: 5_242_880,
      totalParts: 1,
      expiresAt: this.nowIso(),
    };
  }

  adminTask() {
    return {
      title: 'Task',
      due: this.nowIso(),
    };
  }

  adminPerson(personId?: string) {
    return {
      id: personId ?? this.id(),
      fullName: 'Person',
      email: 'person@example.com',
      personType: 'trainer',
      role: 'trainer',
      teamName: '',
      groupIDs: [],
      permissions: [],
      presenceStatus: 'offline',
      isOnline: false,
      linkedPlayerID: null,
      linkedMessengerUserID: null,
      lastActiveAt: null,
      createdAt: this.nowIso(),
      updatedAt: this.nowIso(),
    };
  }

  adminGroup(groupId?: string) {
    return {
      id: groupId ?? this.id(),
      name: 'Gruppe',
      goal: '',
      groupType: 'training',
      memberIDs: [],
      responsibleCoachID: null,
      assistantCoachID: null,
      startsAt: null,
      endsAt: null,
      createdAt: this.nowIso(),
      updatedAt: this.nowIso(),
    };
  }

  adminInvitation(invitationId?: string) {
    return {
      id: invitationId ?? this.id(),
      recipientName: 'Empfanger',
      email: 'invite@example.com',
      method: 'email',
      role: 'trainer',
      teamName: '',
      status: 'pending',
      inviteLink: null,
      sentBy: 'system',
      sentAt: this.nowIso(),
      expiresAt: this.nowIso(),
      updatedAt: this.nowIso(),
    };
  }

  adminAuditEntry() {
    return {
      id: this.id(),
      actorName: 'System',
      targetName: '',
      area: 'general',
      action: 'update',
      details: '',
      timestamp: this.nowIso(),
    };
  }

  adminAuditPage() {
    return {
      items: [],
      nextCursor: null,
    };
  }

  adminSeason(seasonId?: string) {
    return {
      id: seasonId ?? this.id(),
      name: 'Saison',
      startsAt: this.nowIso(),
      endsAt: this.nowIso(),
      status: 'active',
      teamCount: 0,
      playerCount: 0,
      trainerCount: 0,
      createdAt: this.nowIso(),
      updatedAt: this.nowIso(),
    };
  }

  adminClubSettings() {
    return {
      id: null,
      clubName: '',
      clubLogoPath: '',
      primaryColorHex: '#1D4ED8',
      secondaryColorHex: '#0F172A',
      standardTrainingTypes: [],
      defaultVisibility: 'team',
      teamNameConvention: '',
      globalPermissions: [],
    };
  }

  adminMessengerRules() {
    return {
      id: null,
      allowPrivatePlayerChat: false,
      allowDirectTrainerPlayerChat: true,
      defaultReadOnlyForPlayers: false,
      defaultGroups: [],
      allowedChatTypes: ['direct', 'group'],
      groupRuleDescription: '',
    };
  }

  adminBootstrap() {
    return {
      persons: [],
      groups: [],
      invitations: [],
      auditEntries: [],
      seasons: [],
      activeSeasonID: null,
      clubSettings: this.adminClubSettings(),
      messengerRules: this.adminMessengerRules(),
    };
  }

  presentationSettings() {
    return {
      language: 'de',
      region: 'DE',
      timeZoneID: 'Europe/Berlin',
      unitSystem: 'metric',
      appearanceMode: 'system',
      contrastMode: 'normal',
      uiScale: 'medium',
      reduceAnimations: false,
      interactivePreviews: true,
    };
  }

  notificationSettings() {
    return {
      globalEnabled: true,
      modules: [],
    };
  }

  securitySettings() {
    return {
      twoFactorEnabled: false,
      sessions: [],
      apiTokens: [],
      privacyURL: 'https://example.com/privacy',
    };
  }

  appInfoSettings() {
    return {
      version: '1.0.0',
      buildNumber: '1',
      lastUpdateAt: this.nowIso(),
      updateState: 'upToDate',
      changelog: [],
    };
  }

  accountSettings() {
    return {
      contexts: [],
      selectedContextID: null,
      canDeactivateAccount: true,
      canLeaveTeam: true,
    };
  }

  settingsBootstrap() {
    return {
      presentation: this.presentationSettings(),
      notifications: this.notificationSettings(),
      security: this.securitySettings(),
      appInfo: this.appInfoSettings(),
      account: this.accountSettings(),
    };
  }

  emptyObject() {
    return {};
  }

  emptyArray() {
    return [];
  }

  private id(): string {
    return randomUUID();
  }

  private nowIso(): string {
    return new Date().toISOString();
  }
}
