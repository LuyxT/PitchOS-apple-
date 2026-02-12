import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpException,
  Param,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { randomUUID } from 'crypto';

type Json = Record<string, any>;

@Controller()
export class AppController {
  private readonly authUsers: Json[] = [];
  private readonly accessTokens = new Map<string, string>();
  private readonly refreshTokens = new Map<string, string>();
  private readonly onboardingClubs: Json[] = [];
  private readonly trainingPlans: Json[] = [];
  private readonly trainingPhasesByPlan = new Map<string, Json[]>();
  private readonly trainingExercisesByPlan = new Map<string, Json[]>();
  private readonly trainingGroupsByPlan = new Map<string, Json[]>();
  private readonly trainingBriefingsByGroup = new Map<string, Json>();
  private readonly trainingAvailabilityByPlan = new Map<string, Json[]>();
  private readonly trainingDeviationsByPlan = new Map<string, Json[]>();
  private readonly trainingReportsByPlan = new Map<string, Json>();
  private readonly trainingTemplates: Json[] = [];
  private readonly coachProfile: Json = {
    name: 'Luca Möller',
    license: 'UEFA B',
    team: 'PitchInsights FC 1. Mannschaft',
    seasonGoal: 'Top 3 und klare Spielidee'
  };
  private readonly personProfiles: Json[] = [];
  private readonly profileAuditEntries: Json[] = [];
  private readonly players: Json[] = [];
  private readonly calendarCategories: Json[] = [];
  private readonly calendarEvents: Json[] = [];
  private readonly matches: Json[] = [];
  private readonly messageThreads: Json[] = [];
  private readonly feedbackEntries: Json[] = [];
  private readonly transactions: Json[] = [];
  private settingsPresentation: Json = {
    language: 'de',
    region: 'germany',
    timeZoneID: 'Europe/Berlin',
    unitSystem: 'metric',
    appearanceMode: 'light',
    contrastMode: 'standard',
    uiScale: 'medium',
    reduceAnimations: false,
    interactivePreviews: true
  };
  private settingsNotifications: Json = {
    globalEnabled: true,
    modules: [
      { module: 'kalender', push: true, inApp: true, email: false },
      { module: 'trainingsplanung', push: true, inApp: true, email: false },
      { module: 'messenger', push: true, inApp: true, email: false },
      { module: 'spielanalyse', push: false, inApp: true, email: false },
      { module: 'verwaltung', push: true, inApp: true, email: false },
      { module: 'mannschaftskasse', push: true, inApp: true, email: false }
    ]
  };
  private settingsSecurity: Json = {
    twoFactorEnabled: false,
    sessions: [] as Json[],
    apiTokens: [] as Json[],
    privacyURL: 'https://pitchinsights.app/privacy'
  };
  private settingsAppInfo: Json = {
    version: '1.0.0',
    buildNumber: '1',
    lastUpdateAt: new Date().toISOString(),
    updateState: 'current',
    changelog: ['Stabilitätsupdate', 'Backend-Anbindung aktiv']
  };
  private settingsAccount: Json = {
    contexts: [] as Json[],
    selectedContextID: null as string | null,
    canDeactivateAccount: true,
    canLeaveTeam: false
  };

  private readonly defaultCalendarCategoryId = randomUUID();
  private readonly defaultMatchCategoryId = randomUUID();

  constructor() {
    const now = new Date();
    const playerA = randomUUID();
    const playerB = randomUUID();
    const playerC = randomUUID();
    const profileID = randomUUID();
    const contextID = randomUUID();
    const currentSessionID = randomUUID();

    this.trainingTemplates.push({
      id: randomUUID(),
      name: 'Passdreieck',
      baseDescription: 'Technik und Orientierung mit hoher Wiederholungszahl.',
      defaultDuration: 12,
      defaultIntensity: 'medium',
      defaultRequiredPlayers: 8,
      defaultMaterials: [
        { kind: 'baelle', label: 'Bälle', quantity: 8 },
        { kind: 'huetchen', label: 'Hütchen', quantity: 12 },
      ],
    });

    this.players.push(
      {
        id: playerA,
        name: 'Jonas Krüger',
        number: 10,
        position: 'OM',
        status: 'fit',
        dateOfBirth: new Date(2004, 4, 17).toISOString(),
        secondaryPositions: ['ZM'],
        heightCm: 181,
        weightKg: 75,
        preferredFoot: 'right',
        teamName: 'PitchInsights FC 1. Mannschaft',
        squadStatus: 'active',
        joinedAt: new Date(2023, 6, 1).toISOString(),
        roles: ['Spielmacher'],
        groups: ['Offensive'],
        injuryStatus: '',
        notes: '',
        developmentGoals: 'Abschlussquote steigern'
      },
      {
        id: playerB,
        name: 'Luca Meyer',
        number: 7,
        position: 'RA',
        status: 'fit',
        dateOfBirth: new Date(2005, 9, 2).toISOString(),
        secondaryPositions: ['ST'],
        heightCm: 178,
        weightKg: 72,
        preferredFoot: 'right',
        teamName: 'PitchInsights FC 1. Mannschaft',
        squadStatus: 'active',
        joinedAt: new Date(2022, 1, 1).toISOString(),
        roles: ['Flügel'],
        groups: ['Offensive'],
        injuryStatus: '',
        notes: '',
        developmentGoals: '1-gegen-1 verbessern'
      },
      {
        id: playerC,
        name: 'Nico Baum',
        number: 4,
        position: 'IV',
        status: 'unavailable',
        dateOfBirth: new Date(2003, 11, 9).toISOString(),
        secondaryPositions: ['LV'],
        heightCm: 186,
        weightKg: 80,
        preferredFoot: 'left',
        teamName: 'PitchInsights FC 1. Mannschaft',
        squadStatus: 'rehab',
        joinedAt: new Date(2021, 7, 1).toISOString(),
        roles: ['Verteidigung'],
        groups: ['Defensive'],
        injuryStatus: 'Adduktoren',
        notes: '',
        developmentGoals: 'Belastungsaufbau'
      }
    );

    this.calendarCategories.push(
      { id: this.defaultCalendarCategoryId, name: 'Training', colorHex: '#15B78C', isSystem: true },
      { id: this.defaultMatchCategoryId, name: 'Spiel', colorHex: '#2A7FFF', isSystem: true }
    );

    this.calendarEvents.push({
      id: randomUUID(),
      title: 'Teamtraining',
      startDate: new Date(now.getFullYear(), now.getMonth(), now.getDate(), 18, 0, 0).toISOString(),
      endDate: new Date(now.getFullYear(), now.getMonth(), now.getDate(), 19, 30, 0).toISOString(),
      categoryId: this.defaultCalendarCategoryId,
      visibility: 'team',
      audience: 'team',
      audiencePlayerIds: [],
      recurrence: 'none',
      location: 'Platz 1',
      notes: '',
      linkedTrainingPlanID: null,
      eventKind: 'training',
      playerVisibleGoal: 'Ballzirkulation',
      playerVisibleDurationMinutes: 90
    });

    this.matches.push({
      opponent: 'SV Nord',
      date: new Date(now.getFullYear(), now.getMonth(), now.getDate() + 3, 14, 0, 0).toISOString(),
      homeAway: 'Heim'
    });

    this.messageThreads.push({
      title: 'Trainerteam',
      lastMessage: 'Treffpunkt morgen 17:00',
      unreadCount: 2
    });

    this.feedbackEntries.push({
      player: 'Jonas Krüger',
      summary: 'Gutes Umschaltverhalten',
      date: now.toISOString()
    });

    this.transactions.push(
      { title: 'Monatsbeitrag', amount: 35, date: now.toISOString(), type: 'income' },
      { title: 'Getränke', amount: 18, date: now.toISOString(), type: 'expense' }
    );

    this.personProfiles.push({
      id: profileID,
      linkedPlayerID: null,
      linkedAdminPersonID: null,
      core: {
        avatarPath: null,
        firstName: 'Luca',
        lastName: 'Möller',
        dateOfBirth: new Date(1988, 2, 20).toISOString(),
        email: 'coach@pitchinsights.app',
        phone: '+49 170 000000',
        clubName: 'PitchInsights FC',
        roles: ['headCoach'],
        isActive: true,
        internalNotes: ''
      },
      player: null,
      headCoach: {
        licenses: ['UEFA B'],
        education: ['DFB Trainer-Akademie'],
        careerPath: ['U19', '2. Mannschaft'],
        preferredSystems: ['4-3-3', '4-2-3-1'],
        matchPhilosophy: 'Aktives Pressing und mutiger Ballbesitz.',
        trainingPhilosophy: 'Hohe Intensität mit klaren Prinzipien.',
        personalGoals: 'Nachwuchs integrieren.',
        responsibilities: ['Trainingssteuerung', 'Kadersteuerung'],
        isPrimaryContact: true
      },
      assistantCoach: null,
      athleticCoach: null,
      medical: null,
      teamManager: null,
      board: null,
      facility: null,
      lockedFieldKeys: [],
      updatedAt: now.toISOString(),
      updatedBy: 'system'
    });

    const baseContexts = [
      {
        id: contextID,
        clubName: 'PitchInsights FC',
        teamName: '1. Mannschaft',
        roleTitle: 'Chef-Trainer',
        isCurrent: true
      }
    ];
    this.settingsAccount = {
      contexts: baseContexts,
      selectedContextID: contextID,
      canDeactivateAccount: true,
      canLeaveTeam: false
    };
    this.settingsSecurity = {
      twoFactorEnabled: false,
      sessions: [
        {
          id: currentSessionID,
          deviceName: 'MacBook Pro',
          platformName: 'macOS',
          lastUsedAt: now.toISOString(),
          ipAddress: '127.0.0.1',
          location: 'München',
          isCurrentDevice: true
        }
      ],
      apiTokens: [],
      privacyURL: 'https://pitchinsights.app/privacy'
    };

    this.authUsers.push({
      id: randomUUID(),
      email: 'coach@pitchinsights.app',
      password: 'pitchinsights',
      role: 'trainer',
      clubId: null,
      organizationId: null,
      createdAt: now.toISOString(),
    });
    this.onboardingClubs.push({
      id: 'club-pitchinsights-fc',
      name: 'PitchInsights FC',
      region: 'DE',
      league: 'Landesliga',
      inviteCode: 'PITCH-TEAM',
      createdAt: now.toISOString(),
    });
  }

  @Get('bootstrap')
  bootstrap() {
    console.log('[bootstrap] endpoint called');
    return {
      status: 'ok',
      service: 'pitchinsights-backend',
      version: '1.0.0',
      time: new Date().toISOString(),
    };
  }

  @Get()
  root() {
    return { status: 'ok', service: 'pitchinsights-backend' };
  }

  @Get('health')
  health() {
    return { status: 'ok' };
  }

  @Post('auth/register')
  register(@Body() body: Json) {
    const email = String(body?.email ?? '').trim().toLowerCase();
    const password = String(body?.password ?? '');
    const passwordConfirmation = String(body?.passwordConfirmation ?? '');
    const role = String(body?.role ?? '').trim().toLowerCase();
    const inviteCode = String(body?.inviteCode ?? '').trim();

    if (!email || !password) {
      throw new HttpException('E-Mail und Passwort erforderlich', 400);
    }
    if (!role) {
      throw new HttpException('Rolle ist erforderlich', 400);
    }
    if (password != passwordConfirmation) {
      throw new HttpException('Passwörter stimmen nicht überein', 400);
    }
    if (this.authUsers.some((item) => String(item.email).toLowerCase() == email)) {
      throw new HttpException('E-Mail bereits registriert', 409);
    }

    let clubID: string | null = null;
    if (inviteCode.length > 0) {
      const club = this.onboardingClubs.find(
        (item) => String(item.inviteCode).toLowerCase() == inviteCode.toLowerCase(),
      );
      if (!club) {
        throw new HttpException('Einladungscode ungültig', 400);
      }
      clubID = String(club.id);
    }

    const created = {
      id: randomUUID(),
      email,
      password,
      role,
      clubId: clubID,
      organizationId: clubID,
      createdAt: new Date().toISOString(),
    };
    this.authUsers.push(created);

    const { accessToken, refreshToken } = this.issueTokens(created.id);
    return {
      success: true,
      token: accessToken,
      accessToken,
      refreshToken,
      user: this.authUserDTO(created),
    };
  }

  @Post('auth/login')
  login(@Body() body: Json) {
    const email = String(body?.email ?? '').trim().toLowerCase();
    const password = String(body?.password ?? '');
    const user = this.authUsers.find(
      (item) => String(item.email).toLowerCase() == email && String(item.password) == password,
    );

    if (!user) {
      throw new HttpException('Ungültige Anmeldedaten', 401);
    }

    const { accessToken, refreshToken } = this.issueTokens(String(user.id));
    return {
      success: true,
      token: accessToken,
      accessToken,
      refreshToken,
      user: this.authUserDTO(user),
    };
  }

  @Post('auth/refresh')
  refresh(@Body() body: Json) {
    const refreshToken = String(body?.refreshToken ?? '');
    const userID = this.refreshTokens.get(refreshToken);

    if (!refreshToken || !userID) {
      throw new HttpException('Ungültiger Refresh-Token', 401);
    }

    this.refreshTokens.delete(refreshToken);
    const { accessToken, refreshToken: rotatedRefreshToken } = this.issueTokens(userID);
    const user = this.authUsers.find((item) => String(item.id) == userID);
    if (!user) {
      throw new HttpException('Benutzer nicht gefunden', 404);
    }

    return {
      success: true,
      token: accessToken,
      accessToken,
      refreshToken: rotatedRefreshToken,
      user: this.authUserDTO(user),
    };
  }

  @Post('auth/logout')
  logout(@Body() body: Json, @Headers('authorization') authorization?: string) {
    const refreshToken = String(body?.refreshToken ?? '');
    if (refreshToken) {
      this.refreshTokens.delete(refreshToken);
    }
    const accessToken = this.extractBearerToken(authorization);
    if (accessToken) {
      this.accessTokens.delete(accessToken);
    }
    return { success: true };
  }

  @Get('auth/me')
  authMe(@Headers('authorization') authorization?: string) {
    const user = this.requireAuthorizedUser(authorization);
    const clubID = user.clubId == null ? null : String(user.clubId);

    return {
      ...this.authUserDTO(user),
      clubMemberships: clubID == null
        ? []
        : [
          {
            id: `membership-${String(user.id)}`,
            organizationId: clubID,
            teamId: 'team-first',
            role: String(user.role ?? 'trainer'),
            status: 'active',
          },
        ],
      onboardingState: {
        completed: clubID != null,
        completedAt: clubID == null ? null : new Date().toISOString(),
        lastStep: clubID == null ? 'club' : 'complete',
      },
    };
  }

  @Post('onboarding/create-club')
  createClub(@Body() body: Json, @Headers('authorization') authorization?: string) {
    const user = this.requireAuthorizedUser(authorization);
    const name = String(body?.name ?? '').trim();
    const region = String(body?.region ?? '').trim();
    const league = String(body?.league ?? '').trim();

    if (!name) {
      throw new HttpException('Vereinsname ist erforderlich', 400);
    }
    if (!region) {
      throw new HttpException('Region ist erforderlich', 400);
    }

    const club = {
      id: randomUUID(),
      name,
      region,
      league: league.length === 0 ? null : league,
      inviteCode: this.generateInviteCode(),
      createdAt: new Date().toISOString(),
    };
    this.onboardingClubs.push(club);

    user.clubId = club.id;
    user.organizationId = club.id;

    return {
      success: true,
      club: this.onboardingClubDTO(club),
    };
  }

  @Post('onboarding/join-club')
  joinClub(@Body() body: Json, @Headers('authorization') authorization?: string) {
    const user = this.requireAuthorizedUser(authorization);
    const inviteCode = String(body?.inviteCode ?? '').trim();
    if (inviteCode.length === 0) {
      throw new HttpException('Einladungscode ist erforderlich', 400);
    }

    const club = this.onboardingClubs.find(
      (item) => String(item.inviteCode).toLowerCase() == inviteCode.toLowerCase(),
    );
    if (!club) {
      throw new HttpException('Einladungscode ungültig', 400);
    }

    user.clubId = club.id;
    user.organizationId = club.id;

    return {
      success: true,
      club: this.onboardingClubDTO(club),
    };
  }

  @Post('debug/reset-onboarding')
  resetOnboarding(@Headers('authorization') authorization?: string) {
    const user = this.requireAuthorizedUser(authorization);
    user.clubId = null;
    user.organizationId = null;
    return {
      success: true,
      user: this.authUserDTO(user),
    };
  }

  @Get('profile')
  getProfile() {
    return this.coachProfile;
  }

  @Get('profiles')
  listProfiles() {
    return [...this.personProfiles].sort((a, b) => {
      const left = this.profileDisplayName(a).toLowerCase();
      const right = this.profileDisplayName(b).toLowerCase();
      return left.localeCompare(right, 'de');
    });
  }

  @Post('profiles')
  createProfile(@Body() body: Json) {
    const now = new Date().toISOString();
    const created = this.normalizeProfilePayload({
      ...body,
      id: randomUUID(),
      updatedAt: now,
      updatedBy: 'system'
    });
    this.personProfiles.push(created);
    this.appendProfileAudit(created.id, 'created', 'core.displayName', '', this.profileDisplayName(created));
    return created;
  }

  @Put('profiles/:id')
  updateProfile(@Param('id') id: string, @Body() body: Json) {
    const profile = this.requireProfile(id);
    const oldName = this.profileDisplayName(profile);

    const merged = this.normalizeProfilePayload({
      ...profile,
      ...body,
      id,
      updatedAt: new Date().toISOString(),
      updatedBy: String(body?.updatedBy ?? 'system')
    });
    Object.assign(profile, merged);

    this.appendProfileAudit(id, 'updated', 'core.displayName', oldName, this.profileDisplayName(profile));
    return profile;
  }

  @Delete('profiles/:id')
  deleteProfile(@Param('id') id: string) {
    const index = this.personProfiles.findIndex((item) => String(item.id) === id);
    if (index < 0) {
      throw new HttpException('Profile not found', 404);
    }
    this.personProfiles.splice(index, 1);
    return {};
  }

  @Get('profiles/audit')
  profileAudit(@Query('profileId') profileId?: string) {
    if (!profileId || profileId.trim().length === 0) {
      return [...this.profileAuditEntries].sort((a, b) => (a.timestamp < b.timestamp ? 1 : -1));
    }
    return this.profileAuditEntries
      .filter((entry) => String(entry.profileID) === profileId)
      .sort((a, b) => (a.timestamp < b.timestamp ? 1 : -1));
  }

  @Get('players')
  listPlayers() {
    return [...this.players].sort((a, b) => Number(a.number) - Number(b.number));
  }

  @Post('players')
  createPlayer(@Body() body: Json) {
    const now = new Date().toISOString();
    const created = {
      id: randomUUID(),
      name: String(body?.name ?? '').trim() || 'Neuer Spieler',
      number: Math.max(0, Number(body?.number ?? 0)),
      position: String(body?.position ?? 'ST'),
      status: String(body?.status ?? 'fit'),
      dateOfBirth: this.toISO(body?.dateOfBirth),
      secondaryPositions: Array.isArray(body?.secondaryPositions) ? body.secondaryPositions : [],
      heightCm: this.toOptionalInt(body?.heightCm),
      weightKg: this.toOptionalInt(body?.weightKg),
      preferredFoot: body?.preferredFoot ?? null,
      teamName: String(body?.teamName ?? 'PitchInsights FC 1. Mannschaft'),
      squadStatus: String(body?.squadStatus ?? 'active'),
      joinedAt: this.toISO(body?.joinedAt) ?? now,
      roles: Array.isArray(body?.roles) ? body.roles : [],
      groups: Array.isArray(body?.groups) ? body.groups : [],
      injuryStatus: String(body?.injuryStatus ?? ''),
      notes: String(body?.notes ?? ''),
      developmentGoals: String(body?.developmentGoals ?? '')
    };
    this.players.push(created);
    return created;
  }

  @Put('players/:id')
  updatePlayer(@Param('id') id: string, @Body() body: Json) {
    const player = this.requirePlayer(id);
    Object.assign(player, {
      name: String(body?.name ?? player.name),
      number: Math.max(0, Number(body?.number ?? player.number ?? 0)),
      position: String(body?.position ?? player.position ?? 'ST'),
      status: String(body?.status ?? player.status ?? 'fit'),
      dateOfBirth: this.toISO(body?.dateOfBirth) ?? player.dateOfBirth ?? null,
      secondaryPositions: Array.isArray(body?.secondaryPositions)
        ? body.secondaryPositions
        : player.secondaryPositions ?? [],
      heightCm: this.toOptionalInt(body?.heightCm) ?? player.heightCm ?? null,
      weightKg: this.toOptionalInt(body?.weightKg) ?? player.weightKg ?? null,
      preferredFoot: body?.preferredFoot ?? player.preferredFoot ?? null,
      teamName: String(body?.teamName ?? player.teamName ?? 'PitchInsights FC 1. Mannschaft'),
      squadStatus: String(body?.squadStatus ?? player.squadStatus ?? 'active'),
      joinedAt: this.toISO(body?.joinedAt) ?? player.joinedAt ?? null,
      roles: Array.isArray(body?.roles) ? body.roles : player.roles ?? [],
      groups: Array.isArray(body?.groups) ? body.groups : player.groups ?? [],
      injuryStatus: String(body?.injuryStatus ?? player.injuryStatus ?? ''),
      notes: String(body?.notes ?? player.notes ?? ''),
      developmentGoals: String(body?.developmentGoals ?? player.developmentGoals ?? '')
    });
    return player;
  }

  @Delete('players/:id')
  deletePlayer(@Param('id') id: string) {
    const index = this.players.findIndex((item) => String(item.id) === id);
    if (index < 0) {
      throw new HttpException('Player not found', 404);
    }
    this.players.splice(index, 1);
    return {};
  }

  @Get('calendar/categories')
  listCalendarCategories() {
    return this.calendarCategories;
  }

  @Get('calendar/events')
  listCalendarEvents() {
    return [...this.calendarEvents].sort((a, b) => (a.startDate < b.startDate ? -1 : 1));
  }

  @Post('calendar/events')
  createCalendarEvent(@Body() body: Json) {
    const created = {
      id: randomUUID(),
      title: String(body?.title ?? 'Neuer Termin'),
      startDate: this.toISO(body?.startDate) ?? new Date().toISOString(),
      endDate: this.toISO(body?.endDate) ?? new Date(Date.now() + 60 * 60 * 1000).toISOString(),
      categoryId: String(body?.categoryId ?? this.defaultCalendarCategoryId),
      visibility: String(body?.visibility ?? 'team'),
      audience: String(body?.audience ?? 'team'),
      audiencePlayerIds: Array.isArray(body?.audiencePlayerIds) ? body.audiencePlayerIds : [],
      recurrence: String(body?.recurrence ?? 'none'),
      location: String(body?.location ?? ''),
      notes: String(body?.notes ?? ''),
      linkedTrainingPlanID: body?.linkedTrainingPlanID ?? null,
      eventKind: String(body?.eventKind ?? 'generic'),
      playerVisibleGoal: body?.playerVisibleGoal ?? null,
      playerVisibleDurationMinutes:
        body?.playerVisibleDurationMinutes == null ? null : Math.max(0, Number(body.playerVisibleDurationMinutes))
    };
    this.calendarEvents.push(created);
    return created;
  }

  @Put('calendar/events/:id')
  updateCalendarEvent(@Param('id') id: string, @Body() body: Json) {
    const event = this.requireCalendarEvent(id);
    Object.assign(event, {
      title: String(body?.title ?? event.title),
      startDate: this.toISO(body?.startDate) ?? event.startDate,
      endDate: this.toISO(body?.endDate) ?? event.endDate,
      categoryId: String(body?.categoryId ?? event.categoryId),
      visibility: String(body?.visibility ?? event.visibility),
      audience: String(body?.audience ?? event.audience),
      audiencePlayerIds: Array.isArray(body?.audiencePlayerIds) ? body.audiencePlayerIds : event.audiencePlayerIds,
      recurrence: String(body?.recurrence ?? event.recurrence),
      location: String(body?.location ?? event.location ?? ''),
      notes: String(body?.notes ?? event.notes ?? ''),
      linkedTrainingPlanID: body?.linkedTrainingPlanID ?? event.linkedTrainingPlanID ?? null,
      eventKind: String(body?.eventKind ?? event.eventKind ?? 'generic'),
      playerVisibleGoal: body?.playerVisibleGoal ?? event.playerVisibleGoal ?? null,
      playerVisibleDurationMinutes:
        body?.playerVisibleDurationMinutes == null
          ? event.playerVisibleDurationMinutes ?? null
          : Math.max(0, Number(body.playerVisibleDurationMinutes))
    });
    return event;
  }

  @Delete('calendar/events/:id')
  deleteCalendarEvent(@Param('id') id: string) {
    const index = this.calendarEvents.findIndex((item) => String(item.id) === id);
    if (index < 0) {
      throw new HttpException('Calendar event not found', 404);
    }
    this.calendarEvents.splice(index, 1);
    return {};
  }

  @Get('matches')
  listMatches() {
    return this.matches;
  }

  @Get('messages/threads')
  listMessageThreads() {
    return this.messageThreads;
  }

  @Get('feedback')
  listFeedback() {
    return this.feedbackEntries;
  }

  @Get('finance/transactions')
  listTransactions() {
    return this.transactions;
  }

  @Get('settings/bootstrap')
  settingsBootstrap() {
    return {
      presentation: this.settingsPresentation,
      notifications: this.settingsNotifications,
      security: this.settingsSecurity,
      appInfo: this.settingsAppInfo,
      account: this.settingsAccount
    };
  }

  @Put('settings/presentation')
  savePresentation(@Body() body: Json) {
    this.settingsPresentation = {
      ...this.settingsPresentation,
      language: String(body?.language ?? this.settingsPresentation.language),
      region: String(body?.region ?? this.settingsPresentation.region),
      timeZoneID: String(body?.timeZoneID ?? this.settingsPresentation.timeZoneID),
      unitSystem: String(body?.unitSystem ?? this.settingsPresentation.unitSystem),
      appearanceMode: String(body?.appearanceMode ?? this.settingsPresentation.appearanceMode),
      contrastMode: String(body?.contrastMode ?? this.settingsPresentation.contrastMode),
      uiScale: String(body?.uiScale ?? this.settingsPresentation.uiScale),
      reduceAnimations: Boolean(body?.reduceAnimations ?? this.settingsPresentation.reduceAnimations),
      interactivePreviews: Boolean(body?.interactivePreviews ?? this.settingsPresentation.interactivePreviews)
    };
    return this.settingsPresentation;
  }

  @Put('settings/notifications')
  saveNotifications(@Body() body: Json) {
    const modules = Array.isArray(body?.modules)
      ? body.modules.map((module: Json) => ({
          module: String(module?.module ?? ''),
          push: Boolean(module?.push ?? false),
          inApp: Boolean(module?.inApp ?? false),
          email: Boolean(module?.email ?? false)
        }))
      : this.settingsNotifications.modules;
    this.settingsNotifications = {
      globalEnabled: Boolean(body?.globalEnabled ?? this.settingsNotifications.globalEnabled),
      modules
    };
    return this.settingsNotifications;
  }

  @Get('settings/security')
  getSecuritySettings() {
    return this.settingsSecurity;
  }

  @Post('settings/security/password')
  changePassword() {
    return {};
  }

  @Post('settings/security/two-factor')
  toggleTwoFactor(@Body() body: Json) {
    this.settingsSecurity = {
      ...this.settingsSecurity,
      twoFactorEnabled: Boolean(body?.enabled ?? false)
    };
    return this.settingsSecurity;
  }

  @Post('settings/security/sessions/revoke')
  revokeSession(@Body() body: Json) {
    const sessionID = String(body?.sessionID ?? '');
    const sessions = Array.isArray(this.settingsSecurity.sessions) ? this.settingsSecurity.sessions : [];
    this.settingsSecurity = {
      ...this.settingsSecurity,
      sessions: sessions.filter((item: Json) => String(item.id) !== sessionID || Boolean(item.isCurrentDevice))
    };
    return this.settingsSecurity;
  }

  @Post('settings/security/sessions/revoke-all')
  revokeAllSessions() {
    const sessions = Array.isArray(this.settingsSecurity.sessions) ? this.settingsSecurity.sessions : [];
    this.settingsSecurity = {
      ...this.settingsSecurity,
      sessions: sessions.filter((item: Json) => Boolean(item.isCurrentDevice))
    };
    return this.settingsSecurity;
  }

  @Get('settings/app-info')
  appInfo() {
    this.settingsAppInfo = {
      ...this.settingsAppInfo,
      lastUpdateAt: new Date().toISOString()
    };
    return this.settingsAppInfo;
  }

  @Post('settings/feedback')
  submitSettingsFeedback(@Body() body: Json) {
    this.feedbackEntries.unshift({
      player: String(body?.category ?? 'Feedback'),
      summary: String(body?.message ?? ''),
      date: new Date().toISOString()
    });
    return {};
  }

  @Post('settings/account/context')
  switchSettingsContext(@Body() body: Json) {
    const contextID = String(body?.contextID ?? '');
    const contexts = Array.isArray(this.settingsAccount.contexts) ? this.settingsAccount.contexts : [];
    const updatedContexts = contexts.map((context: Json) => ({
      ...context,
      isCurrent: String(context.id) == contextID
    }));
    this.settingsAccount = {
      ...this.settingsAccount,
      contexts: updatedContexts,
      selectedContextID: contextID
    };
    return this.settingsAccount;
  }

  @Post('settings/account/deactivate')
  deactivateAccount() {
    return {};
  }

  @Post('settings/account/leave-team')
  leaveTeam() {
    return {};
  }

  @Get('training/plans')
  listTrainingPlans(@Query('limit') limitQuery?: string) {
    const limit = Number(limitQuery ?? 80);
    const items = [...this.trainingPlans]
      .sort((a, b) => (a.date < b.date ? 1 : -1))
      .slice(0, Number.isFinite(limit) && limit > 0 ? limit : 80);

    return { items, nextCursor: null };
  }

  @Get('training/plans/:id')
  getTrainingPlan(@Param('id') id: string) {
    return this.buildTrainingEnvelope(id);
  }

  @Post('training/plans')
  createTrainingPlan(@Body() body: Json) {
    const now = new Date().toISOString();
    const created = {
      id: randomUUID(),
      title: String(body?.title ?? '').trim() || 'Training',
      date: this.toISO(body?.date) ?? now,
      location: String(body?.location ?? ''),
      mainGoal: String(body?.mainGoal ?? ''),
      secondaryGoals: Array.isArray(body?.secondaryGoals) ? body.secondaryGoals.map(String) : [],
      status: String(body?.status ?? 'draft').toLowerCase(),
      linkedMatchID: body?.linkedMatchID ?? null,
      calendarEventID: null,
      createdAt: now,
      updatedAt: now,
    };

    this.trainingPlans.push(created);
    this.trainingPhasesByPlan.set(created.id, []);
    this.trainingExercisesByPlan.set(created.id, []);
    this.trainingGroupsByPlan.set(created.id, []);
    this.trainingAvailabilityByPlan.set(created.id, []);
    this.trainingDeviationsByPlan.set(created.id, []);

    return created;
  }

  @Put('training/plans/:id')
  updateTrainingPlan(@Param('id') id: string, @Body() body: Json) {
    const plan = this.requirePlan(id);

    plan.title = String(body?.title ?? plan.title);
    plan.date = this.toISO(body?.date) ?? plan.date;
    plan.location = String(body?.location ?? plan.location ?? '');
    plan.mainGoal = String(body?.mainGoal ?? plan.mainGoal ?? '');
    plan.secondaryGoals = Array.isArray(body?.secondaryGoals)
      ? body.secondaryGoals.map(String)
      : plan.secondaryGoals;
    plan.status = String(body?.status ?? plan.status ?? 'draft').toLowerCase();
    plan.linkedMatchID = body?.linkedMatchID ?? null;
    plan.updatedAt = new Date().toISOString();

    return plan;
  }

  @Delete('training/plans/:id')
  deleteTrainingPlan(@Param('id') id: string) {
    const index = this.trainingPlans.findIndex((item) => item.id === id);
    if (index < 0) {
      throw new HttpException('Training plan not found', 404);
    }

    this.trainingPlans.splice(index, 1);
    this.trainingPhasesByPlan.delete(id);
    this.trainingExercisesByPlan.delete(id);
    this.trainingGroupsByPlan.delete(id);
    this.trainingAvailabilityByPlan.delete(id);
    this.trainingDeviationsByPlan.delete(id);
    this.trainingReportsByPlan.delete(id);

    return {};
  }

  @Put('training/plans/:id/phases')
  saveTrainingPhases(@Param('id') id: string, @Body() body: Json) {
    this.requirePlan(id);

    const phases: Json[] = Array.isArray(body?.phases)
      ? body.phases.map((phase: Json, index: number) => ({
          id: String(phase?.id ?? randomUUID()),
          planID: id,
          orderIndex: Number.isFinite(Number(phase?.orderIndex)) ? Number(phase.orderIndex) : index,
          type: String(phase?.type ?? 'main'),
          title: String(phase?.title ?? 'Phase'),
          durationMinutes: Math.max(1, Number(phase?.durationMinutes ?? 10)),
          goal: String(phase?.goal ?? ''),
          intensity: String(phase?.intensity ?? 'medium'),
          description: String(phase?.description ?? ''),
          isCompletedLive: Boolean(phase?.isCompletedLive ?? false),
        }))
      : [];

    this.trainingPhasesByPlan.set(id, phases);

    const currentExercises = this.trainingExercisesByPlan.get(id) ?? [];
    const phaseIDSet = new Set(phases.map((item) => item.id));
    this.trainingExercisesByPlan.set(
      id,
      currentExercises.filter((exercise) => phaseIDSet.has(exercise.phaseID)),
    );

    return phases;
  }

  @Put('training/plans/:id/exercises')
  saveTrainingExercises(@Param('id') id: string, @Body() body: Json) {
    this.requirePlan(id);

    const knownPhases = this.trainingPhasesByPlan.get(id) ?? [];
    const phaseIDSet = new Set(knownPhases.map((item) => item.id));

    const exercises: Json[] = Array.isArray(body?.exercises)
      ? body.exercises
          .filter((exercise: Json) => phaseIDSet.has(String(exercise?.phaseID ?? '')))
          .map((exercise: Json, index: number) => ({
            id: String(exercise?.id ?? randomUUID()),
            phaseID: String(exercise?.phaseID),
            orderIndex: Number.isFinite(Number(exercise?.orderIndex)) ? Number(exercise.orderIndex) : index,
            name: String(exercise?.name ?? 'Übung'),
            description: String(exercise?.description ?? ''),
            durationMinutes: Math.max(1, Number(exercise?.durationMinutes ?? 10)),
            intensity: String(exercise?.intensity ?? 'medium'),
            requiredPlayers: Math.max(1, Number(exercise?.requiredPlayers ?? 1)),
            materials: Array.isArray(exercise?.materials)
              ? exercise.materials.map((material: Json) => ({
                  kind: String(material?.kind ?? 'sonstiges'),
                  label: String(material?.label ?? ''),
                  quantity: Math.max(0, Number(material?.quantity ?? 0)),
                }))
              : [],
            excludedPlayerIDs: Array.isArray(exercise?.excludedPlayerIDs)
              ? exercise.excludedPlayerIDs
              : [],
            templateSourceID: exercise?.templateSourceID ?? null,
            isSkippedLive: Boolean(exercise?.isSkippedLive ?? false),
            actualDurationMinutes:
              exercise?.actualDurationMinutes == null
                ? null
                : Math.max(1, Number(exercise.actualDurationMinutes)),
          }))
      : [];

    this.trainingExercisesByPlan.set(id, exercises);
    return exercises;
  }

  @Post('training/templates')
  createTrainingTemplate(@Body() body: Json) {
    const template = {
      id: randomUUID(),
      name: String(body?.name ?? '').trim() || 'Neue Vorlage',
      baseDescription: String(body?.baseDescription ?? ''),
      defaultDuration: Math.max(1, Number(body?.defaultDuration ?? 10)),
      defaultIntensity: String(body?.defaultIntensity ?? 'medium'),
      defaultRequiredPlayers: Math.max(1, Number(body?.defaultRequiredPlayers ?? 1)),
      defaultMaterials: Array.isArray(body?.defaultMaterials)
        ? body.defaultMaterials.map((material: Json) => ({
            kind: String(material?.kind ?? 'sonstiges'),
            label: String(material?.label ?? ''),
            quantity: Math.max(0, Number(material?.quantity ?? 0)),
          }))
        : [],
    };

    this.trainingTemplates.unshift(template);
    return template;
  }

  @Get('training/templates')
  listTrainingTemplates(
    @Query('query') query?: string,
    @Query('limit') limitQuery?: string,
  ) {
    const needle = String(query ?? '').trim().toLowerCase();
    const limit = Number(limitQuery ?? 120);

    const filtered = this.trainingTemplates.filter((item) =>
      needle.length === 0
        ? true
        : item.name.toLowerCase().includes(needle) || item.baseDescription.toLowerCase().includes(needle),
    );

    return {
      items: filtered.slice(0, Number.isFinite(limit) && limit > 0 ? limit : 120),
      nextCursor: null,
    };
  }

  @Post('training/plans/:id/groups')
  createTrainingGroup(@Param('id') id: string, @Body() body: Json) {
    this.requirePlan(id);

    const groups = this.trainingGroupsByPlan.get(id) ?? [];
    const created = {
      id: String(body?.id ?? randomUUID()),
      planID: id,
      name: String(body?.name ?? 'Gruppe'),
      goal: String(body?.goal ?? ''),
      playerIDs: Array.isArray(body?.playerIDs) ? body.playerIDs : [],
      headCoachUserID: String(body?.headCoachUserID ?? 'coach.default'),
      assistantCoachUserID: body?.assistantCoachUserID ?? null,
    };

    groups.push(created);
    this.trainingGroupsByPlan.set(id, groups);
    return created;
  }

  @Put('training/groups/:id')
  updateTrainingGroup(@Param('id') groupID: string, @Body() body: Json) {
    const { planID, group } = this.requireGroup(groupID);

    group.name = String(body?.name ?? group.name);
    group.goal = String(body?.goal ?? group.goal ?? '');
    group.playerIDs = Array.isArray(body?.playerIDs) ? body.playerIDs : group.playerIDs;
    group.headCoachUserID = String(body?.headCoachUserID ?? group.headCoachUserID ?? 'coach.default');
    group.assistantCoachUserID = body?.assistantCoachUserID ?? null;

    this.trainingGroupsByPlan.set(planID, this.trainingGroupsByPlan.get(planID) ?? []);
    return group;
  }

  @Put('training/groups/:id/briefing')
  saveTrainingGroupBriefing(@Param('id') groupID: string, @Body() body: Json) {
    this.requireGroup(groupID);

    const briefing = {
      id: this.trainingBriefingsByGroup.get(groupID)?.id ?? randomUUID(),
      groupID,
      goal: String(body?.goal ?? ''),
      coachingPoints: String(body?.coachingPoints ?? ''),
      focusPoints: String(body?.focusPoints ?? ''),
      commonMistakes: String(body?.commonMistakes ?? ''),
      targetIntensity: String(body?.targetIntensity ?? 'medium'),
    };

    this.trainingBriefingsByGroup.set(groupID, briefing);
    return briefing;
  }

  @Put('training/plans/:id/participants')
  assignTrainingParticipants(@Param('id') id: string, @Body() body: Json) {
    this.requirePlan(id);

    const availability: Json[] = Array.isArray(body?.availability)
      ? body.availability.map((entry: Json) => ({
          playerID: entry?.playerID,
          availability: String(entry?.availability ?? 'fit'),
          isAbsent: Boolean(entry?.isAbsent ?? false),
          isLimited: Boolean(entry?.isLimited ?? false),
          note: String(entry?.note ?? ''),
        }))
      : [];

    this.trainingAvailabilityByPlan.set(id, availability);
    return availability;
  }

  @Post('training/plans/:id/live/start')
  startTrainingLive(@Param('id') id: string) {
    const plan = this.requirePlan(id);
    plan.status = 'live';
    plan.updatedAt = new Date().toISOString();
    return plan;
  }

  @Put('training/plans/:id/live/state')
  saveTrainingLiveState(@Param('id') id: string, @Body() body: Json) {
    this.requirePlan(id);

    if (Array.isArray(body?.phases)) {
      this.saveTrainingPhases(id, { phases: body.phases });
    }
    if (Array.isArray(body?.exercises)) {
      this.saveTrainingExercises(id, { exercises: body.exercises });
    }

    return this.buildTrainingEnvelope(id);
  }

  @Post('training/plans/:id/live/deviations')
  createTrainingLiveDeviation(@Param('id') id: string, @Body() body: Json) {
    this.requirePlan(id);

    const item = {
      id: randomUUID(),
      planID: id,
      phaseID: body?.phaseID ?? null,
      exerciseID: body?.exerciseID ?? null,
      kind: String(body?.kind ?? 'timeAdjusted'),
      plannedValue: String(body?.plannedValue ?? ''),
      actualValue: String(body?.actualValue ?? ''),
      note: String(body?.note ?? ''),
      timestamp: this.toISO(body?.timestamp) ?? new Date().toISOString(),
    };

    const list = this.trainingDeviationsByPlan.get(id) ?? [];
    list.push(item);
    this.trainingDeviationsByPlan.set(id, list);

    return item;
  }

  @Post('training/plans/:id/report')
  createTrainingReport(@Param('id') id: string, @Body() body: Json) {
    this.requirePlan(id);

    const report = {
      id: this.trainingReportsByPlan.get(id)?.id ?? randomUUID(),
      planID: id,
      generatedAt: new Date().toISOString(),
      plannedTotalMinutes: Math.max(0, Number(body?.plannedTotalMinutes ?? 0)),
      actualTotalMinutes: Math.max(0, Number(body?.actualTotalMinutes ?? 0)),
      attendance: Array.isArray(body?.attendance) ? body.attendance : [],
      groupFeedback: Array.isArray(body?.groupFeedback) ? body.groupFeedback : [],
      playerNotes: Array.isArray(body?.playerNotes) ? body.playerNotes : [],
      summary: String(body?.summary ?? ''),
    };

    this.trainingReportsByPlan.set(id, report);
    return report;
  }

  @Get('training/plans/:id/report')
  getTrainingReport(@Param('id') id: string) {
    this.requirePlan(id);
    const report = this.trainingReportsByPlan.get(id);
    if (!report) {
      throw new HttpException('Training report not found', 404);
    }
    return report;
  }

  @Post('training/plans/:id/calendar-link')
  linkTrainingToCalendar(@Param('id') id: string, @Body() body: Json) {
    const plan = this.requirePlan(id);
    const now = new Date();
    const startDate = now.toISOString();
    const endDate = new Date(now.getTime() + 90 * 60 * 1000).toISOString();

    const event = {
      id: randomUUID(),
      title: plan.title,
      startDate,
      endDate,
      categoryId: this.defaultCalendarCategoryId,
      visibility: 'team',
      audience: 'team',
      audiencePlayerIds: [],
      recurrence: 'none',
      location: plan.location,
      notes: '',
      linkedTrainingPlanID: id,
      eventKind: 'training',
      playerVisibleGoal:
        String(body?.playersViewLevel ?? 'basic') === 'basicPlusGoalDuration' ? plan.mainGoal : null,
      playerVisibleDurationMinutes: 90,
    };

    plan.calendarEventID = event.id;
    plan.updatedAt = new Date().toISOString();
    this.calendarEvents.push(event);
    return event;
  }

  @Post('training/plans/:id/duplicate')
  duplicateTrainingPlan(@Param('id') id: string, @Body() body: Json) {
    const source = this.requirePlan(id);
    const now = new Date().toISOString();

    const copy = {
      ...source,
      id: randomUUID(),
      title: String(body?.name ?? `${source.title} Kopie`),
      date: this.toISO(body?.targetDate) ?? source.date,
      status: 'draft',
      calendarEventID: null,
      createdAt: now,
      updatedAt: now,
    };

    this.trainingPlans.push(copy);

    const sourcePhases = this.trainingPhasesByPlan.get(id) ?? [];
    const copiedPhases = sourcePhases.map((phase) => ({
      ...phase,
      id: randomUUID(),
      planID: copy.id,
    }));
    this.trainingPhasesByPlan.set(copy.id, copiedPhases);

    const phaseMap = new Map(sourcePhases.map((phase, idx) => [phase.id, copiedPhases[idx]?.id]));
    const sourceExercises = this.trainingExercisesByPlan.get(id) ?? [];
    const copiedExercises = sourceExercises
      .map((exercise) => ({
        ...exercise,
        id: randomUUID(),
        phaseID: phaseMap.get(exercise.phaseID) ?? exercise.phaseID,
      }))
      .filter((exercise) => copiedPhases.some((phase) => phase.id === exercise.phaseID));

    this.trainingExercisesByPlan.set(copy.id, copiedExercises);

    const sourceGroups = this.trainingGroupsByPlan.get(id) ?? [];
    const copiedGroups = sourceGroups.map((group) => ({ ...group, id: randomUUID(), planID: copy.id }));
    this.trainingGroupsByPlan.set(copy.id, copiedGroups);

    const sourceAvailability = this.trainingAvailabilityByPlan.get(id) ?? [];
    this.trainingAvailabilityByPlan.set(copy.id, [...sourceAvailability]);

    const sourceDeviations = this.trainingDeviationsByPlan.get(id) ?? [];
    this.trainingDeviationsByPlan.set(
      copy.id,
      sourceDeviations.map((item) => ({ ...item, id: randomUUID(), planID: copy.id })),
    );

    return copy;
  }

  @Get('trainings')
  trainingsList() {
    return this.trainingPlans.map((plan) => ({
      title: plan.title,
      date: plan.date,
      focus: plan.mainGoal,
    }));
  }

  private buildTrainingEnvelope(planID: string) {
    const plan = this.requirePlan(planID);
    const phases = this.trainingPhasesByPlan.get(planID) ?? [];
    const exercises = this.trainingExercisesByPlan.get(planID) ?? [];
    const groups = this.trainingGroupsByPlan.get(planID) ?? [];
    const briefings = groups
      .map((group) => this.trainingBriefingsByGroup.get(group.id))
      .filter((item): item is Json => Boolean(item));
    const availability = this.trainingAvailabilityByPlan.get(planID) ?? [];
    const deviations = this.trainingDeviationsByPlan.get(planID) ?? [];
    const report = this.trainingReportsByPlan.get(planID) ?? null;

    return {
      plan,
      phases,
      exercises,
      groups,
      briefings,
      report,
      availability,
      deviations,
    };
  }

  private requirePlan(id: string) {
    const plan = this.trainingPlans.find((item) => item.id === id);
    if (!plan) {
      throw new HttpException('Training plan not found', 404);
    }
    return plan;
  }

  private requireGroup(groupID: string) {
    for (const [planID, groups] of this.trainingGroupsByPlan.entries()) {
      const group = groups.find((item) => item.id === groupID);
      if (group) {
        return { planID, group };
      }
    }
    throw new HttpException('Training group not found', 404);
  }

  private requireProfile(id: string) {
    const profile = this.personProfiles.find((item) => String(item.id) === id);
    if (!profile) {
      throw new HttpException('Profile not found', 404);
    }
    return profile;
  }

  private requirePlayer(id: string) {
    const player = this.players.find((item) => String(item.id) === id);
    if (!player) {
      throw new HttpException('Player not found', 404);
    }
    return player;
  }

  private requireCalendarEvent(id: string) {
    const event = this.calendarEvents.find((item) => String(item.id) === id);
    if (!event) {
      throw new HttpException('Calendar event not found', 404);
    }
    return event;
  }

  private toISO(value: unknown): string | null {
    if (typeof value !== 'string' || value.trim().length === 0) {
      return null;
    }
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) {
      return null;
    }
    return parsed.toISOString();
  }

  private toOptionalInt(value: unknown): number | null {
    if (value == null) {
      return null;
    }
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) {
      return null;
    }
    return Math.trunc(parsed);
  }

  private appendProfileAudit(
    profileID: string,
    action: string,
    fieldPath: string,
    oldValue: string,
    newValue: string
  ) {
    this.profileAuditEntries.unshift({
      id: randomUUID(),
      profileID,
      actorName: 'System',
      fieldPath,
      area: 'core',
      oldValue,
      newValue,
      action,
      timestamp: new Date().toISOString()
    });
  }

  private profileDisplayName(profile: Json): string {
    const core = (profile.core ?? {}) as Json;
    const firstName = String(core.firstName ?? '').trim();
    const lastName = String(core.lastName ?? '').trim();
    return [firstName, lastName].filter((value) => value.length > 0).join(' ').trim();
  }

  private normalizeProfilePayload(profile: Json): Json {
    const now = new Date().toISOString();
    const core = (profile.core ?? {}) as Json;
    return {
      id: String(profile.id ?? randomUUID()),
      linkedPlayerID: profile.linkedPlayerID ?? null,
      linkedAdminPersonID: profile.linkedAdminPersonID ?? null,
      core: {
        avatarPath: core.avatarPath ?? null,
        firstName: String(core.firstName ?? ''),
        lastName: String(core.lastName ?? ''),
        dateOfBirth: this.toISO(core.dateOfBirth) ?? null,
        email: String(core.email ?? ''),
        phone: core.phone == null ? null : String(core.phone),
        clubName: String(core.clubName ?? ''),
        roles: Array.isArray(core.roles) ? core.roles.map((item) => String(item)) : [],
        isActive: Boolean(core.isActive ?? true),
        internalNotes: String(core.internalNotes ?? '')
      },
      player: profile.player ?? null,
      headCoach: profile.headCoach ?? null,
      assistantCoach: profile.assistantCoach ?? null,
      athleticCoach: profile.athleticCoach ?? null,
      medical: profile.medical ?? null,
      teamManager: profile.teamManager ?? null,
      board: profile.board ?? null,
      facility: profile.facility ?? null,
      lockedFieldKeys: Array.isArray(profile.lockedFieldKeys) ? profile.lockedFieldKeys : [],
      updatedAt: this.toISO(profile.updatedAt) ?? now,
      updatedBy: String(profile.updatedBy ?? 'system')
    };
  }

  private issueTokens(userID: string): { accessToken: string; refreshToken: string } {
    const accessToken = `pi_access_${randomUUID()}`;
    const refreshToken = `pi_refresh_${randomUUID()}`;
    this.accessTokens.set(accessToken, userID);
    this.refreshTokens.set(refreshToken, userID);
    return { accessToken, refreshToken };
  }

  private extractBearerToken(authorization?: string): string | null {
    if (!authorization) {
      return null;
    }
    const trimmed = authorization.trim();
    if (!trimmed.startsWith('Bearer ')) {
      return null;
    }
    return trimmed.slice('Bearer '.length).trim();
  }

  private authUserDTO(user: Json): Json {
    return {
      id: String(user.id ?? ''),
      email: String(user.email ?? ''),
      role: user.role == null ? null : String(user.role),
      clubId: user.clubId == null ? null : String(user.clubId),
      organizationId: user.organizationId ?? user.clubId ?? null,
      createdAt: user.createdAt ?? null,
    };
  }

  private requireAuthorizedUser(authorization?: string): Json {
    const accessToken = this.extractBearerToken(authorization);
    if (!accessToken) {
      throw new HttpException('Authorization erforderlich', 401);
    }
    const userID = this.accessTokens.get(accessToken);
    if (!userID) {
      throw new HttpException('Ungültiger Access-Token', 401);
    }
    const user = this.authUsers.find((item) => String(item.id) == userID);
    if (!user) {
      throw new HttpException('Benutzer nicht gefunden', 404);
    }
    return user;
  }

  private generateInviteCode(): string {
    return `PITCH-${randomUUID().split('-')[0].toUpperCase()}`;
  }

  private onboardingClubDTO(club: Json): Json {
    return {
      id: String(club.id ?? ''),
      name: String(club.name ?? ''),
      region: club.region == null ? null : String(club.region),
      league: club.league == null ? null : String(club.league),
      inviteCode: club.inviteCode == null ? null : String(club.inviteCode),
    };
  }
}
