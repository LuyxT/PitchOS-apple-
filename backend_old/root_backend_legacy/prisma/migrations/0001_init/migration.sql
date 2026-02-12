-- CreateEnum
CREATE TYPE "RoleType" AS ENUM ('ADMIN', 'TRAINER', 'CO_TRAINER', 'ANALYST', 'TEAM_MANAGER', 'PHYSIO', 'PLAYER', 'BOARD');

-- CreateEnum
CREATE TYPE "PermissionType" AS ENUM ('TRAINING_CREATE', 'TRAINING_EDIT', 'TRAINING_DELETE', 'SQUAD_EDIT', 'PEOPLE_MANAGE', 'MESSENGER_MANAGE', 'GROUPS_MANAGE', 'REPORT_RELEASE', 'SEASON_MANAGE', 'SETTINGS_EDIT', 'FILES_MANAGE', 'CASH_MANAGE');

-- CreateEnum
CREATE TYPE "InvitationStatus" AS ENUM ('OPEN', 'ACCEPTED', 'EXPIRED', 'WITHDRAWN');

-- CreateEnum
CREATE TYPE "TeamMemberStatus" AS ENUM ('ACTIVE', 'INACTIVE', 'ABSENT');

-- CreateEnum
CREATE TYPE "CalendarVisibility" AS ENUM ('PRIVATE', 'TEAM', 'PUBLIC');

-- CreateEnum
CREATE TYPE "CalendarEventKind" AS ENUM ('GENERIC', 'TRAINING', 'MATCH');

-- CreateEnum
CREATE TYPE "TrainingStatus" AS ENUM ('DRAFT', 'SCHEDULED', 'LIVE', 'COMPLETED');

-- CreateEnum
CREATE TYPE "TrainingPhaseType" AS ENUM ('WARMUP', 'ACTIVATION', 'MAIN', 'COOLDOWN');

-- CreateEnum
CREATE TYPE "TrainingIntensity" AS ENUM ('LOW', 'MEDIUM', 'HIGH');

-- CreateEnum
CREATE TYPE "TacticsOpponentMode" AS ENUM ('HIDDEN', 'MARKERS', 'FORMATION');

-- CreateEnum
CREATE TYPE "AnalysisDrawingKind" AS ENUM ('LINE', 'ARROW', 'CIRCLE', 'RECTANGLE');

-- CreateEnum
CREATE TYPE "MessengerChatType" AS ENUM ('DIRECT', 'GROUP');

-- CreateEnum
CREATE TYPE "MessengerWritePolicy" AS ENUM ('TRAINER_ONLY', 'ALL_MEMBERS', 'CUSTOM');

-- CreateEnum
CREATE TYPE "MessageType" AS ENUM ('TEXT', 'IMAGE', 'VIDEO', 'ANALYSIS_CLIP_REFERENCE');

-- CreateEnum
CREATE TYPE "MessageStatus" AS ENUM ('QUEUED', 'UPLOADING', 'SENT', 'DELIVERED', 'READ', 'FAILED');

-- CreateEnum
CREATE TYPE "FileType" AS ENUM ('VIDEO', 'CLIP', 'TACTICBOARD', 'TRAININGPLAN', 'IMAGE', 'DOCUMENT', 'EXPORT', 'ANALYSIS_EXPORT', 'OTHER');

-- CreateEnum
CREATE TYPE "FileVisibility" AS ENUM ('TEAM', 'RESTRICTED', 'EXPLICIT');

-- CreateEnum
CREATE TYPE "FileUploadStatus" AS ENUM ('REGISTERED', 'UPLOADING', 'READY', 'FAILED');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('PAID', 'OPEN', 'OVERDUE');

-- CreateEnum
CREATE TYPE "CashTransactionType" AS ENUM ('INCOME', 'EXPENSE');

-- CreateEnum
CREATE TYPE "SettingsThemeMode" AS ENUM ('LIGHT', 'DARK', 'SYSTEM');

-- CreateEnum
CREATE TYPE "SyncState" AS ENUM ('SYNCED', 'PENDING', 'FAILED');

-- CreateTable
CREATE TABLE "Organization" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "logoFileId" TEXT,
    "colors" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Organization_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Team" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "shortName" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Team_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Role" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "type" "RoleType" NOT NULL,
    "permissions" "PermissionType"[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Role_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "User" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "firstName" TEXT NOT NULL,
    "lastName" TEXT NOT NULL,
    "phone" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "primaryTeamId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UserRole" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "roleId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UserRole_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TeamMembership" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "status" "TeamMemberStatus" NOT NULL DEFAULT 'ACTIVE',
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "leftAt" TIMESTAMP(3),

    CONSTRAINT "TeamMembership_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RefreshToken" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Profile" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "birthDate" TIMESTAMP(3),
    "clubMembership" TEXT,
    "notes" TEXT,
    "avatarFileId" TEXT,
    "activeStatus" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Profile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProfileVersion" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "changedBy" TEXT NOT NULL,
    "diff" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ProfileVersion_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Player" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "userId" TEXT,
    "jerseyNumber" INTEGER,
    "primaryPosition" TEXT NOT NULL,
    "secondaryPositions" TEXT[],
    "fitnessStatus" TEXT NOT NULL,
    "squadStatus" TEXT NOT NULL,
    "availabilityStatus" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Player_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PlayerProfile" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "heightCm" INTEGER,
    "weightKg" INTEGER,
    "preferredFoot" TEXT,
    "preferredRole" TEXT,
    "goals" TEXT[],
    "biography" TEXT,
    "injuryHistory" TEXT,
    "resilience" TEXT,

    CONSTRAINT "PlayerProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrainerProfile" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "licenses" TEXT[],
    "education" TEXT[],
    "philosophy" TEXT,
    "goals" TEXT[],
    "careerHistory" TEXT,
    "responsibilities" TEXT[],
    "contactLead" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "TrainerProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PhysioProfile" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "qualifications" TEXT[],
    "specializations" TEXT[],
    "assignedGroups" TEXT[],

    CONSTRAINT "PhysioProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ManagerProfile" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "function" TEXT,
    "responsibilities" TEXT[],
    "communicationScope" TEXT,

    CONSTRAINT "ManagerProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BoardProfile" (
    "id" TEXT NOT NULL,
    "profileId" TEXT NOT NULL,
    "boardFunction" TEXT,
    "responsibilities" TEXT[],
    "mandateFrom" TIMESTAMP(3),
    "mandateUntil" TIMESTAMP(3),

    CONSTRAINT "BoardProfile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CalendarEvent" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "startAt" TIMESTAMP(3) NOT NULL,
    "endAt" TIMESTAMP(3) NOT NULL,
    "visibility" "CalendarVisibility" NOT NULL DEFAULT 'TEAM',
    "category" TEXT,
    "eventKind" "CalendarEventKind" NOT NULL DEFAULT 'GENERIC',
    "linkedTrainingPlanId" TEXT,
    "playerVisibleGoal" TEXT,
    "playerVisibleDurationMin" INTEGER,
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CalendarEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrainingPlan" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "location" TEXT,
    "mainGoal" TEXT NOT NULL,
    "secondaryGoals" TEXT[],
    "status" "TrainingStatus" NOT NULL DEFAULT 'DRAFT',
    "linkedMatchId" TEXT,
    "calendarEventId" TEXT,
    "syncState" "SyncState" NOT NULL DEFAULT 'SYNCED',
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TrainingPlan_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrainingPhase" (
    "id" TEXT NOT NULL,
    "trainingPlanId" TEXT NOT NULL,
    "orderIndex" INTEGER NOT NULL,
    "type" "TrainingPhaseType" NOT NULL,
    "title" TEXT NOT NULL,
    "durationMinutes" INTEGER NOT NULL,
    "goal" TEXT NOT NULL,
    "intensity" "TrainingIntensity" NOT NULL,
    "description" TEXT,
    "completedLive" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "TrainingPhase_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrainingExercise" (
    "id" TEXT NOT NULL,
    "phaseId" TEXT NOT NULL,
    "orderIndex" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "durationMinutes" INTEGER NOT NULL,
    "intensity" "TrainingIntensity" NOT NULL,
    "requiredPlayers" INTEGER,
    "materials" JSONB,
    "excludedPlayerIds" TEXT[],
    "templateSourceId" TEXT,
    "skippedLive" BOOLEAN NOT NULL DEFAULT false,
    "actualDurationMin" INTEGER,

    CONSTRAINT "TrainingExercise_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrainingTemplate" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TrainingTemplate_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrainingGroup" (
    "id" TEXT NOT NULL,
    "trainingPlanId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "goal" TEXT,
    "playerIds" TEXT[],
    "headCoachUserId" TEXT NOT NULL,
    "assistantCoachUserId" TEXT,

    CONSTRAINT "TrainingGroup_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrainingGroupBriefing" (
    "id" TEXT NOT NULL,
    "trainingGroupId" TEXT NOT NULL,
    "goal" TEXT,
    "coachingPoints" TEXT,
    "focusPoints" TEXT,
    "commonMistakes" TEXT,
    "targetIntensity" "TrainingIntensity",

    CONSTRAINT "TrainingGroupBriefing_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrainingDeviation" (
    "id" TEXT NOT NULL,
    "trainingPlanId" TEXT NOT NULL,
    "phaseId" TEXT,
    "exerciseId" TEXT,
    "kind" TEXT NOT NULL,
    "plannedValue" TEXT,
    "actualValue" TEXT,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "TrainingDeviation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TrainingReport" (
    "id" TEXT NOT NULL,
    "trainingPlanId" TEXT NOT NULL,
    "generatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "plannedTotalMin" INTEGER NOT NULL,
    "actualTotalMin" INTEGER NOT NULL,
    "attendance" JSONB NOT NULL,
    "groupFeedback" JSONB NOT NULL,
    "playerNotes" JSONB NOT NULL,
    "summary" TEXT,

    CONSTRAINT "TrainingReport_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TacticsBoard" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "scenarioName" TEXT NOT NULL,
    "placements" JSONB NOT NULL,
    "benchPlayerIds" TEXT[],
    "excludedPlayerIds" TEXT[],
    "opponentMode" "TacticsOpponentMode" NOT NULL DEFAULT 'HIDDEN',
    "opponentMarkers" JSONB,
    "drawings" JSONB,
    "version" INTEGER NOT NULL DEFAULT 1,
    "cloudFileId" TEXT,
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TacticsBoard_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AnalysisSession" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "videoFileId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "matchId" TEXT,
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AnalysisSession_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AnalysisMarker" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "playerId" TEXT,
    "category" TEXT,
    "comment" TEXT,
    "timeMs" INTEGER NOT NULL,
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AnalysisMarker_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AnalysisClip" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "videoFileId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "startMs" INTEGER NOT NULL,
    "endMs" INTEGER NOT NULL,
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AnalysisClip_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AnalysisDrawing" (
    "id" TEXT NOT NULL,
    "sessionId" TEXT NOT NULL,
    "kind" "AnalysisDrawingKind" NOT NULL,
    "points" JSONB NOT NULL,
    "color" TEXT NOT NULL,
    "isTemporary" BOOLEAN NOT NULL DEFAULT false,
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3),

    CONSTRAINT "AnalysisDrawing_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MessengerChat" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "name" TEXT,
    "type" "MessengerChatType" NOT NULL,
    "writePolicy" "MessengerWritePolicy" NOT NULL DEFAULT 'ALL_MEMBERS',
    "isArchived" BOOLEAN NOT NULL DEFAULT false,
    "temporaryUntil" TIMESTAMP(3),
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MessengerChat_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MessengerChatMember" (
    "id" TEXT NOT NULL,
    "chatId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "muted" BOOLEAN NOT NULL DEFAULT false,
    "pinned" BOOLEAN NOT NULL DEFAULT false,
    "canWrite" BOOLEAN NOT NULL DEFAULT true,
    "unreadCount" INTEGER NOT NULL DEFAULT 0,
    "lastReadMessageId" TEXT,
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MessengerChatMember_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MessengerMessage" (
    "id" TEXT NOT NULL,
    "chatId" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "type" "MessageType" NOT NULL,
    "text" TEXT,
    "context" TEXT,
    "attachmentFileId" TEXT,
    "clipId" TEXT,
    "analysisSessionId" TEXT,
    "status" "MessageStatus" NOT NULL DEFAULT 'SENT',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MessengerMessage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MessengerReadReceipt" (
    "id" TEXT NOT NULL,
    "messageId" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "readAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MessengerReadReceipt_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CloudFolder" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "parentId" TEXT,
    "name" TEXT NOT NULL,
    "path" TEXT NOT NULL,
    "createdBy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CloudFolder_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CloudFile" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "teamId" TEXT,
    "ownerUserId" TEXT NOT NULL,
    "folderId" TEXT,
    "name" TEXT NOT NULL,
    "originalName" TEXT NOT NULL,
    "type" "FileType" NOT NULL,
    "mimeType" TEXT NOT NULL,
    "sizeBytes" BIGINT NOT NULL,
    "storageKey" TEXT NOT NULL,
    "moduleHint" TEXT,
    "tags" TEXT[],
    "visibility" "FileVisibility" NOT NULL DEFAULT 'TEAM',
    "explicitShareIds" TEXT[],
    "checksum" TEXT,
    "uploadStatus" "FileUploadStatus" NOT NULL DEFAULT 'REGISTERED',
    "deletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CloudFile_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "TeamQuota" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "quotaBytes" BIGINT NOT NULL,
    "usedBytes" BIGINT NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "TeamQuota_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CashTransaction" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "category" TEXT NOT NULL,
    "description" TEXT,
    "type" "CashTransactionType" NOT NULL,
    "playerId" TEXT,
    "responsibleUserId" TEXT,
    "comment" TEXT,
    "paymentStatus" "PaymentStatus" NOT NULL DEFAULT 'PAID',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CashTransaction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MonthlyContribution" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "playerId" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "dueDate" TIMESTAMP(3) NOT NULL,
    "status" "PaymentStatus" NOT NULL DEFAULT 'OPEN',
    "paidAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MonthlyContribution_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "CashGoal" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "targetAmount" DECIMAL(12,2) NOT NULL,
    "currentProgress" DECIMAL(12,2) NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CashGoal_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Invitation" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "inviteToken" TEXT NOT NULL,
    "roleType" "RoleType" NOT NULL,
    "teamId" TEXT,
    "status" "InvitationStatus" NOT NULL DEFAULT 'OPEN',
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "createdBy" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "acceptedAt" TIMESTAMP(3),

    CONSTRAINT "Invitation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Season" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT false,
    "isLocked" BOOLEAN NOT NULL DEFAULT false,
    "isArchived" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Season_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AuditLog" (
    "id" TEXT NOT NULL,
    "organizationId" TEXT NOT NULL,
    "actorUserId" TEXT NOT NULL,
    "area" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "targetType" TEXT NOT NULL,
    "targetId" TEXT NOT NULL,
    "payload" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UserSettings" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "language" TEXT NOT NULL DEFAULT 'de',
    "region" TEXT NOT NULL DEFAULT 'DE',
    "timezone" TEXT NOT NULL DEFAULT 'Europe/Berlin',
    "unitSystem" TEXT NOT NULL DEFAULT 'metric',
    "themeMode" "SettingsThemeMode" NOT NULL DEFAULT 'SYSTEM',
    "highContrast" BOOLEAN NOT NULL DEFAULT false,
    "uiScale" TEXT NOT NULL DEFAULT 'medium',
    "reduceAnimations" BOOLEAN NOT NULL DEFAULT false,
    "interactivePreviews" BOOLEAN NOT NULL DEFAULT true,
    "notificationsEnabled" BOOLEAN NOT NULL DEFAULT true,
    "moduleNotifications" JSONB,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UserSettings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WidgetSnapshot" (
    "id" TEXT NOT NULL,
    "teamId" TEXT NOT NULL,
    "module" TEXT NOT NULL,
    "size" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "WidgetSnapshot_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Organization_name_idx" ON "Organization"("name");

-- CreateIndex
CREATE INDEX "Team_organizationId_idx" ON "Team"("organizationId");

-- CreateIndex
CREATE UNIQUE INDEX "Team_organizationId_name_key" ON "Team"("organizationId", "name");

-- CreateIndex
CREATE INDEX "Role_organizationId_idx" ON "Role"("organizationId");

-- CreateIndex
CREATE UNIQUE INDEX "Role_organizationId_type_key" ON "Role"("organizationId", "type");

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "User_organizationId_idx" ON "User"("organizationId");

-- CreateIndex
CREATE UNIQUE INDEX "UserRole_userId_roleId_key" ON "UserRole"("userId", "roleId");

-- CreateIndex
CREATE UNIQUE INDEX "TeamMembership_teamId_userId_key" ON "TeamMembership"("teamId", "userId");

-- CreateIndex
CREATE INDEX "RefreshToken_userId_idx" ON "RefreshToken"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "Profile_userId_key" ON "Profile"("userId");

-- CreateIndex
CREATE INDEX "Profile_userId_idx" ON "Profile"("userId");

-- CreateIndex
CREATE INDEX "ProfileVersion_profileId_idx" ON "ProfileVersion"("profileId");

-- CreateIndex
CREATE INDEX "Player_teamId_idx" ON "Player"("teamId");

-- CreateIndex
CREATE UNIQUE INDEX "PlayerProfile_profileId_key" ON "PlayerProfile"("profileId");

-- CreateIndex
CREATE UNIQUE INDEX "TrainerProfile_profileId_key" ON "TrainerProfile"("profileId");

-- CreateIndex
CREATE UNIQUE INDEX "PhysioProfile_profileId_key" ON "PhysioProfile"("profileId");

-- CreateIndex
CREATE UNIQUE INDEX "ManagerProfile_profileId_key" ON "ManagerProfile"("profileId");

-- CreateIndex
CREATE UNIQUE INDEX "BoardProfile_profileId_key" ON "BoardProfile"("profileId");

-- CreateIndex
CREATE INDEX "CalendarEvent_teamId_startAt_idx" ON "CalendarEvent"("teamId", "startAt");

-- CreateIndex
CREATE INDEX "TrainingPlan_teamId_date_idx" ON "TrainingPlan"("teamId", "date");

-- CreateIndex
CREATE INDEX "TrainingPhase_trainingPlanId_orderIndex_idx" ON "TrainingPhase"("trainingPlanId", "orderIndex");

-- CreateIndex
CREATE INDEX "TrainingExercise_phaseId_orderIndex_idx" ON "TrainingExercise"("phaseId", "orderIndex");

-- CreateIndex
CREATE INDEX "TrainingTemplate_teamId_idx" ON "TrainingTemplate"("teamId");

-- CreateIndex
CREATE UNIQUE INDEX "TrainingGroupBriefing_trainingGroupId_key" ON "TrainingGroupBriefing"("trainingGroupId");

-- CreateIndex
CREATE INDEX "TrainingDeviation_trainingPlanId_createdAt_idx" ON "TrainingDeviation"("trainingPlanId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "TrainingReport_trainingPlanId_key" ON "TrainingReport"("trainingPlanId");

-- CreateIndex
CREATE INDEX "TacticsBoard_teamId_updatedAt_idx" ON "TacticsBoard"("teamId", "updatedAt");

-- CreateIndex
CREATE INDEX "AnalysisSession_teamId_createdAt_idx" ON "AnalysisSession"("teamId", "createdAt");

-- CreateIndex
CREATE INDEX "AnalysisMarker_sessionId_timeMs_idx" ON "AnalysisMarker"("sessionId", "timeMs");

-- CreateIndex
CREATE INDEX "AnalysisClip_sessionId_createdAt_idx" ON "AnalysisClip"("sessionId", "createdAt");

-- CreateIndex
CREATE INDEX "AnalysisDrawing_sessionId_createdAt_idx" ON "AnalysisDrawing"("sessionId", "createdAt");

-- CreateIndex
CREATE INDEX "MessengerChat_teamId_updatedAt_idx" ON "MessengerChat"("teamId", "updatedAt");

-- CreateIndex
CREATE UNIQUE INDEX "MessengerChatMember_chatId_userId_key" ON "MessengerChatMember"("chatId", "userId");

-- CreateIndex
CREATE INDEX "MessengerMessage_chatId_createdAt_idx" ON "MessengerMessage"("chatId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "MessengerReadReceipt_messageId_userId_key" ON "MessengerReadReceipt"("messageId", "userId");

-- CreateIndex
CREATE INDEX "CloudFolder_organizationId_parentId_idx" ON "CloudFolder"("organizationId", "parentId");

-- CreateIndex
CREATE UNIQUE INDEX "CloudFolder_organizationId_path_key" ON "CloudFolder"("organizationId", "path");

-- CreateIndex
CREATE INDEX "CloudFile_organizationId_teamId_deletedAt_idx" ON "CloudFile"("organizationId", "teamId", "deletedAt");

-- CreateIndex
CREATE INDEX "CloudFile_type_createdAt_idx" ON "CloudFile"("type", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "CloudFile_storageKey_key" ON "CloudFile"("storageKey");

-- CreateIndex
CREATE UNIQUE INDEX "TeamQuota_organizationId_key" ON "TeamQuota"("organizationId");

-- CreateIndex
CREATE INDEX "CashTransaction_teamId_date_idx" ON "CashTransaction"("teamId", "date");

-- CreateIndex
CREATE INDEX "MonthlyContribution_teamId_dueDate_idx" ON "MonthlyContribution"("teamId", "dueDate");

-- CreateIndex
CREATE INDEX "CashGoal_teamId_endDate_idx" ON "CashGoal"("teamId", "endDate");

-- CreateIndex
CREATE UNIQUE INDEX "Invitation_inviteToken_key" ON "Invitation"("inviteToken");

-- CreateIndex
CREATE INDEX "Invitation_organizationId_status_idx" ON "Invitation"("organizationId", "status");

-- CreateIndex
CREATE INDEX "Season_organizationId_isActive_idx" ON "Season"("organizationId", "isActive");

-- CreateIndex
CREATE INDEX "AuditLog_organizationId_createdAt_idx" ON "AuditLog"("organizationId", "createdAt");

-- CreateIndex
CREATE INDEX "AuditLog_actorUserId_idx" ON "AuditLog"("actorUserId");

-- CreateIndex
CREATE UNIQUE INDEX "UserSettings_userId_key" ON "UserSettings"("userId");

-- CreateIndex
CREATE INDEX "WidgetSnapshot_teamId_module_size_idx" ON "WidgetSnapshot"("teamId", "module", "size");

-- AddForeignKey
ALTER TABLE "Team" ADD CONSTRAINT "Team_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Role" ADD CONSTRAINT "Role_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "User" ADD CONSTRAINT "User_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "User" ADD CONSTRAINT "User_primaryTeamId_fkey" FOREIGN KEY ("primaryTeamId") REFERENCES "Team"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserRole" ADD CONSTRAINT "UserRole_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserRole" ADD CONSTRAINT "UserRole_roleId_fkey" FOREIGN KEY ("roleId") REFERENCES "Role"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TeamMembership" ADD CONSTRAINT "TeamMembership_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TeamMembership" ADD CONSTRAINT "TeamMembership_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RefreshToken" ADD CONSTRAINT "RefreshToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Profile" ADD CONSTRAINT "Profile_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProfileVersion" ADD CONSTRAINT "ProfileVersion_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Player" ADD CONSTRAINT "Player_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Player" ADD CONSTRAINT "Player_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlayerProfile" ADD CONSTRAINT "PlayerProfile_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainerProfile" ADD CONSTRAINT "TrainerProfile_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PhysioProfile" ADD CONSTRAINT "PhysioProfile_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ManagerProfile" ADD CONSTRAINT "ManagerProfile_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BoardProfile" ADD CONSTRAINT "BoardProfile_profileId_fkey" FOREIGN KEY ("profileId") REFERENCES "Profile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CalendarEvent" ADD CONSTRAINT "CalendarEvent_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingPlan" ADD CONSTRAINT "TrainingPlan_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingPhase" ADD CONSTRAINT "TrainingPhase_trainingPlanId_fkey" FOREIGN KEY ("trainingPlanId") REFERENCES "TrainingPlan"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingExercise" ADD CONSTRAINT "TrainingExercise_phaseId_fkey" FOREIGN KEY ("phaseId") REFERENCES "TrainingPhase"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingGroup" ADD CONSTRAINT "TrainingGroup_trainingPlanId_fkey" FOREIGN KEY ("trainingPlanId") REFERENCES "TrainingPlan"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingGroupBriefing" ADD CONSTRAINT "TrainingGroupBriefing_trainingGroupId_fkey" FOREIGN KEY ("trainingGroupId") REFERENCES "TrainingGroup"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TrainingReport" ADD CONSTRAINT "TrainingReport_trainingPlanId_fkey" FOREIGN KEY ("trainingPlanId") REFERENCES "TrainingPlan"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TacticsBoard" ADD CONSTRAINT "TacticsBoard_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AnalysisSession" ADD CONSTRAINT "AnalysisSession_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AnalysisMarker" ADD CONSTRAINT "AnalysisMarker_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "AnalysisSession"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AnalysisClip" ADD CONSTRAINT "AnalysisClip_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "AnalysisSession"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AnalysisDrawing" ADD CONSTRAINT "AnalysisDrawing_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "AnalysisSession"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MessengerChat" ADD CONSTRAINT "MessengerChat_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MessengerChatMember" ADD CONSTRAINT "MessengerChatMember_chatId_fkey" FOREIGN KEY ("chatId") REFERENCES "MessengerChat"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MessengerChatMember" ADD CONSTRAINT "MessengerChatMember_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MessengerMessage" ADD CONSTRAINT "MessengerMessage_chatId_fkey" FOREIGN KEY ("chatId") REFERENCES "MessengerChat"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MessengerMessage" ADD CONSTRAINT "MessengerMessage_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MessengerReadReceipt" ADD CONSTRAINT "MessengerReadReceipt_messageId_fkey" FOREIGN KEY ("messageId") REFERENCES "MessengerMessage"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MessengerReadReceipt" ADD CONSTRAINT "MessengerReadReceipt_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CloudFolder" ADD CONSTRAINT "CloudFolder_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CloudFile" ADD CONSTRAINT "CloudFile_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CloudFile" ADD CONSTRAINT "CloudFile_ownerUserId_fkey" FOREIGN KEY ("ownerUserId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CloudFile" ADD CONSTRAINT "CloudFile_folderId_fkey" FOREIGN KEY ("folderId") REFERENCES "CloudFolder"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "TeamQuota" ADD CONSTRAINT "TeamQuota_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CashTransaction" ADD CONSTRAINT "CashTransaction_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CashTransaction" ADD CONSTRAINT "CashTransaction_responsibleUserId_fkey" FOREIGN KEY ("responsibleUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MonthlyContribution" ADD CONSTRAINT "MonthlyContribution_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CashGoal" ADD CONSTRAINT "CashGoal_teamId_fkey" FOREIGN KEY ("teamId") REFERENCES "Team"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Invitation" ADD CONSTRAINT "Invitation_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Season" ADD CONSTRAINT "Season_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AuditLog" ADD CONSTRAINT "AuditLog_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES "Organization"("id") ON DELETE CASCADE ON UPDATE CASCADE;

