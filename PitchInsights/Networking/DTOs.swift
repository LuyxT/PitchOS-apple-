import Foundation

struct CoachProfileDTO: Decodable {
    let name: String
    let license: String
    let team: String
    let seasonGoal: String
}

struct ProfileCoreDTO: Codable {
    let avatarPath: String?
    let firstName: String
    let lastName: String
    let dateOfBirth: Date?
    let email: String
    let phone: String?
    let clubName: String
    let roles: [String]
    let isActive: Bool
    let internalNotes: String
}

struct PlayerRoleProfileDTO: Codable {
    let primaryPosition: String
    let secondaryPositions: [String]
    let jerseyNumber: Int?
    let heightCm: Int?
    let weightKg: Int?
    let preferredFoot: String?
    let preferredSystemRole: String
    let seasonGoals: String
    let longTermGoals: String
    let pathway: String
    let loadCapacity: String
    let injuryHistory: String
    let availability: String
}

struct HeadCoachProfileDTO: Codable {
    let licenses: [String]
    let education: [String]
    let careerPath: [String]
    let preferredSystems: [String]
    let matchPhilosophy: String
    let trainingPhilosophy: String
    let personalGoals: String
    let responsibilities: [String]
    let isPrimaryContact: Bool
}

struct AssistantCoachProfileDTO: Codable {
    let licenses: [String]
    let focusAreas: [String]
    let operationalFocus: String
    let groupResponsibilities: [String]
    let trainingInvolvement: String
}

struct AthleticCoachProfileDTO: Codable {
    let certifications: [String]
    let focusAreas: [String]
    let ageGroupExperience: [String]
    let planningInvolvement: String
    let groupResponsibilities: [String]
}

struct MedicalProfileDTO: Codable {
    let education: [String]
    let additionalQualifications: [String]
    let specialties: [String]
    let assignedTeams: [String]
    let organizationalAvailability: String
    let protectedInternalNotes: String
}

struct TeamManagerProfileDTO: Codable {
    let clubFunction: String
    let responsibilities: [String]
    let operationalTasks: [String]
    let communicationOwnership: String
    let internalAvailability: String
}

struct BoardProfileDTO: Codable {
    let boardFunction: String
    let termStart: Date?
    let termEnd: Date?
    let responsibilityAreas: [String]
    let contactOptions: [String]
}

struct FacilityProfileDTO: Codable {
    let responsibilities: [String]
    let facilities: [String]
    let availability: String
}

struct PersonProfileDTO: Codable {
    let id: String
    let linkedPlayerID: UUID?
    let linkedAdminPersonID: UUID?
    let core: ProfileCoreDTO
    let player: PlayerRoleProfileDTO?
    let headCoach: HeadCoachProfileDTO?
    let assistantCoach: AssistantCoachProfileDTO?
    let athleticCoach: AthleticCoachProfileDTO?
    let medical: MedicalProfileDTO?
    let teamManager: TeamManagerProfileDTO?
    let board: BoardProfileDTO?
    let facility: FacilityProfileDTO?
    let lockedFieldKeys: [String]
    let updatedAt: Date
    let updatedBy: String
}

struct UpsertPersonProfileRequest: Encodable {
    let id: String?
    let linkedPlayerID: UUID?
    let linkedAdminPersonID: UUID?
    let core: ProfileCoreDTO
    let player: PlayerRoleProfileDTO?
    let headCoach: HeadCoachProfileDTO?
    let assistantCoach: AssistantCoachProfileDTO?
    let athleticCoach: AthleticCoachProfileDTO?
    let medical: MedicalProfileDTO?
    let teamManager: TeamManagerProfileDTO?
    let board: BoardProfileDTO?
    let facility: FacilityProfileDTO?
    let lockedFieldKeys: [String]
}

struct ProfileAuditEntryDTO: Codable {
    let id: String
    let profileID: String
    let actorName: String
    let fieldPath: String
    let area: String
    let oldValue: String
    let newValue: String
    let timestamp: Date
}

struct PlayerDTO: Decodable {
    let id: UUID?
    let name: String
    let number: Int
    let position: String
    let status: String
    let dateOfBirth: Date?
    let secondaryPositions: [String]?
    let heightCm: Int?
    let weightKg: Int?
    let preferredFoot: String?
    let teamName: String?
    let squadStatus: String?
    let joinedAt: Date?
    let roles: [String]?
    let groups: [String]?
    let injuryStatus: String?
    let notes: String?
    let developmentGoals: String?
}

struct CalendarEventDTO: Decodable {
    let id: UUID
    let title: String
    let startDate: Date
    let endDate: Date
    let categoryId: UUID
    let visibility: String
    let audience: String
    let audiencePlayerIds: [UUID]?
    let recurrence: String
    let location: String?
    let notes: String?
    let linkedTrainingPlanID: UUID?
    let eventKind: String?
    let playerVisibleGoal: String?
    let playerVisibleDurationMinutes: Int?
}

struct CalendarCategoryDTO: Decodable {
    let id: UUID
    let name: String
    let colorHex: String
    let isSystem: Bool
}

struct CreateCalendarEventRequest: Encodable {
    let title: String
    let startDate: Date
    let endDate: Date
    let categoryId: UUID
    let visibility: String
    let audience: String
    let audiencePlayerIds: [UUID]
    let recurrence: String
    let location: String
    let notes: String
    let linkedTrainingPlanID: UUID?
    let eventKind: String
    let playerVisibleGoal: String?
    let playerVisibleDurationMinutes: Int?

    init(from event: CalendarEvent) {
        title = event.title
        startDate = event.startDate
        endDate = event.endDate
        categoryId = event.categoryID
        visibility = event.visibility.rawValue
        audience = event.audience.rawValue
        audiencePlayerIds = event.audiencePlayerIDs
        recurrence = event.recurrence.rawValue
        location = event.location
        notes = event.notes
        linkedTrainingPlanID = event.linkedTrainingPlanID
        eventKind = event.eventKind.rawValue
        playerVisibleGoal = event.playerVisibleGoal
        playerVisibleDurationMinutes = event.playerVisibleDurationMinutes
    }
}

struct UpdateCalendarEventRequest: Encodable {
    let title: String
    let startDate: Date
    let endDate: Date
    let categoryId: UUID
    let visibility: String
    let audience: String
    let audiencePlayerIds: [UUID]
    let recurrence: String
    let location: String
    let notes: String
    let linkedTrainingPlanID: UUID?
    let eventKind: String
    let playerVisibleGoal: String?
    let playerVisibleDurationMinutes: Int?
}

struct UpsertPlayerRequest: Encodable {
    let id: UUID
    let name: String
    let number: Int
    let position: String
    let status: String
    let dateOfBirth: Date?
    let secondaryPositions: [String]
    let heightCm: Int?
    let weightKg: Int?
    let preferredFoot: String?
    let teamName: String
    let squadStatus: String
    let joinedAt: Date?
    let roles: [String]
    let groups: [String]
    let injuryStatus: String
    let notes: String
    let developmentGoals: String

    init(from player: Player) {
        id = player.id
        name = player.name
        number = player.number
        position = player.primaryPosition.rawValue
        status = player.availability.backendValue
        dateOfBirth = player.dateOfBirth
        secondaryPositions = player.secondaryPositions.map(\.rawValue)
        heightCm = player.heightCm
        weightKg = player.weightKg
        preferredFoot = player.preferredFoot?.backendValue
        teamName = player.teamName
        squadStatus = player.squadStatus.backendValue
        joinedAt = player.joinedAt
        roles = player.roles
        groups = player.groups
        injuryStatus = player.injuryStatus
        notes = player.notes
        developmentGoals = player.developmentGoals
    }
}

struct TacticsStateDTO: Decodable {
    let activeScenarioID: UUID?
    let scenarios: [TacticsScenario]
    let boards: [TacticsBoardState]
}

struct SaveTacticsStateRequest: Encodable {
    let activeScenarioID: UUID?
    let scenarios: [TacticsScenario]
    let boards: [TacticsBoardState]
}

struct AnalysisVideoRegisterRequest: Encodable {
    let filename: String
    let fileSize: Int64
    let mimeType: String
    let sha256: String
    let importedAt: Date
}

struct AnalysisVideoRegisterResponse: Decodable {
    let videoID: String
    let uploadURL: String
    let uploadHeaders: [String: String]
    let expiresAt: Date?
}

struct AnalysisVideoCompleteRequest: Encodable {
    let fileSize: Int64
    let sha256: String
    let completedAt: Date
}

struct AnalysisVideoCompleteResponse: Decodable {
    let videoID: String
    let playbackReady: Bool
}

struct SignedPlaybackURLResponse: Decodable {
    let signedPlaybackURL: String
    let expiresAt: Date?
}

struct AnalysisSessionDTO: Decodable {
    let id: String
    let videoID: String
    let title: String
    let matchID: UUID?
    let teamID: String?
    let createdAt: Date
    let updatedAt: Date
}

struct CreateAnalysisSessionRequest: Encodable {
    let videoID: String
    let title: String
    let matchID: UUID?
    let teamID: String?
}

struct AnalysisMarkerDTO: Decodable {
    let id: String
    let sessionID: String
    let videoID: String
    let timeSeconds: Double
    let categoryID: UUID?
    let comment: String
    let playerID: UUID?
    let createdAt: Date
    let updatedAt: Date
}

struct CreateAnalysisMarkerRequest: Encodable {
    let sessionID: String
    let videoID: String
    let timeSeconds: Double
    let categoryID: UUID?
    let comment: String
    let playerID: UUID?
}

struct UpdateAnalysisMarkerRequest: Encodable {
    let categoryID: UUID?
    let comment: String
    let playerID: UUID?
}

struct AnalysisClipDTO: Decodable {
    let id: String
    let sessionID: String
    let videoID: String
    let name: String
    let startSeconds: Double
    let endSeconds: Double
    let playerIDs: [UUID]
    let note: String
    let createdAt: Date
    let updatedAt: Date
}

struct CreateAnalysisClipRequest: Encodable {
    let sessionID: String
    let videoID: String
    let name: String
    let startSeconds: Double
    let endSeconds: Double
    let playerIDs: [UUID]
    let note: String
}

struct UpdateAnalysisClipRequest: Encodable {
    let name: String
    let startSeconds: Double
    let endSeconds: Double
    let playerIDs: [UUID]
    let note: String
}

struct AnalysisDrawingPointDTO: Codable {
    let x: Double
    let y: Double
}

struct AnalysisDrawingDTO: Codable {
    let id: String?
    let localID: UUID?
    let tool: String
    let points: [AnalysisDrawingPointDTO]
    let colorHex: String
    let isTemporary: Bool
    let timeSeconds: Double
    let createdAt: Date
}

struct SaveAnalysisDrawingsRequest: Encodable {
    let drawings: [AnalysisDrawingDTO]
}

struct AnalysisSessionEnvelopeDTO: Decodable {
    let session: AnalysisSessionDTO
    let markers: [AnalysisMarkerDTO]
    let clips: [AnalysisClipDTO]
    let drawings: [AnalysisDrawingDTO]
}

struct ShareAnalysisClipRequest: Encodable {
    let playerIDs: [UUID]
    let threadID: UUID?
    let message: String
}

struct ShareAnalysisClipResponse: Decodable {
    let threadID: UUID
    let messageIDs: [String]
}

struct AuthMeDTO: Decodable {
    let userID: String
    let displayName: String
    let role: String
    let clubID: String
    let teamIDs: [String]
}

struct MessengerParticipantDTO: Codable {
    let userID: String
    let displayName: String
    let role: String
    let playerID: UUID?
    let mutedUntil: Date?
    let canWrite: Bool
    let joinedAt: Date
}

struct MessengerChatDTO: Decodable {
    let id: String
    let title: String
    let type: String
    let participants: [MessengerParticipantDTO]
    let lastMessagePreview: String?
    let lastMessageAt: Date?
    let unreadCount: Int
    let pinned: Bool
    let muted: Bool
    let archived: Bool
    let writePermission: String
    let temporaryUntil: Date?
    let createdAt: Date
    let updatedAt: Date
}

struct MessengerChatsPageDTO: Decodable {
    let items: [MessengerChatDTO]
    let nextCursor: String?
}

struct CreateDirectChatRequest: Encodable {
    let participantUserID: String
}

struct CreateGroupChatRequest: Encodable {
    let title: String
    let participantUserIDs: [String]
    let writePermission: String
    let temporaryUntil: Date?
}

struct UpdateChatRequest: Encodable {
    let name: String?
    let muted: Bool?
    let pinned: Bool?
    let archived: Bool?
    let writePolicy: String?
    let temporaryUntil: Date?
}

struct MessengerAttachmentDTO: Codable {
    let mediaID: String
    let kind: String
    let filename: String
    let mimeType: String
    let fileSize: Int64
}

struct MessengerClipReferenceDTO: Codable {
    let clipID: String
    let analysisSessionID: String
    let videoAssetID: String
    let clipName: String
    let timeStart: Double
    let timeEnd: Double
    let matchID: UUID?
}

struct MessengerReadReceiptDTO: Codable {
    let userID: String
    let userName: String
    let readAt: Date
}

struct MessengerMessageDTO: Decodable {
    let id: String
    let chatID: String
    let senderUserID: String
    let senderName: String
    let type: String
    let text: String
    let contextLabel: String?
    let attachment: MessengerAttachmentDTO?
    let clipReference: MessengerClipReferenceDTO?
    let createdAt: Date
    let updatedAt: Date
    let status: String
    let readBy: [MessengerReadReceiptDTO]
}

struct MessengerMessagesPageDTO: Decodable {
    let items: [MessengerMessageDTO]
    let nextCursor: String?
}

struct CreateMessageRequest: Encodable {
    let type: String
    let text: String
    let contextLabel: String?
    let attachmentID: String?
    let clipReference: MessengerClipReferenceDTO?
}

struct MarkChatReadRequest: Encodable {
    let lastReadMessageID: String?
}

struct MessengerSearchResultDTO: Decodable {
    let id: String
    let type: String
    let chatID: String?
    let messageID: String?
    let title: String
    let subtitle: String
    let occurredAt: Date?
}

struct MessengerSearchPageDTO: Decodable {
    let items: [MessengerSearchResultDTO]
    let nextCursor: String?
}

struct MessengerMediaRegisterRequest: Encodable {
    let filename: String
    let fileSize: Int64
    let mimeType: String
    let sha256: String
}

struct MessengerMediaRegisterResponse: Decodable {
    let mediaID: String
    let uploadURL: String
    let uploadHeaders: [String: String]
    let expiresAt: Date?
}

struct MessengerMediaCompleteRequest: Encodable {
    let fileSize: Int64
    let sha256: String
    let completedAt: Date
}

struct MessengerMediaCompleteResponse: Decodable {
    let mediaID: String
    let ready: Bool
}

struct MessengerMediaDownloadResponse: Decodable {
    let signedURL: String
    let expiresAt: Date?
}

struct MessengerRealtimeTokenResponse: Decodable {
    let token: String
    let expiresAt: Date?
}

struct MessengerRealtimeEventDTO: Decodable {
    let eventCursor: String
    let type: String
    let chat: MessengerChatDTO?
    let message: MessengerMessageDTO?
    let chatID: String?
    let messageID: String?
    let receipt: MessengerReadReceiptDTO?
    let userID: String?
}

struct TrainingPlansPageDTO: Decodable {
    let items: [TrainingPlanDTO]
    let nextCursor: String?
}

struct TrainingPlanDTO: Decodable {
    let id: String
    let title: String
    let date: Date
    let location: String
    let mainGoal: String
    let secondaryGoals: [String]
    let status: String
    let linkedMatchID: UUID?
    let calendarEventID: UUID?
    let createdAt: Date
    let updatedAt: Date
}

struct TrainingPhaseDTO: Codable {
    let id: String
    let planID: String
    let orderIndex: Int
    let type: String
    let title: String
    let durationMinutes: Int
    let goal: String
    let intensity: String
    let description: String
    let isCompletedLive: Bool
}

struct TrainingMaterialQuantityDTO: Codable {
    let kind: String
    let label: String
    let quantity: Int
}

struct TrainingExerciseDTO: Codable {
    let id: String
    let phaseID: String
    let orderIndex: Int
    let name: String
    let description: String
    let durationMinutes: Int
    let intensity: String
    let requiredPlayers: Int
    let materials: [TrainingMaterialQuantityDTO]
    let excludedPlayerIDs: [UUID]
    let templateSourceID: String?
    let isSkippedLive: Bool
    let actualDurationMinutes: Int?
}

struct TrainingGroupDTO: Codable {
    let id: String
    let planID: String
    let name: String
    let goal: String
    let playerIDs: [UUID]
    let headCoachUserID: String
    let assistantCoachUserID: String?
}

struct TrainingGroupBriefingDTO: Codable {
    let id: String
    let groupID: String
    let goal: String
    let coachingPoints: String
    let focusPoints: String
    let commonMistakes: String
    let targetIntensity: String
}

struct TrainingAttendanceEntryDTO: Codable {
    let playerID: UUID
    let status: String
    let note: String
}

struct TrainingGroupFeedbackDTO: Codable {
    let id: String
    let groupID: String
    let trainerUserID: String
    let feedback: String
}

struct TrainingPlayerNoteDTO: Codable {
    let playerID: UUID
    let note: String
}

struct TrainingReportDTO: Codable {
    let id: String
    let planID: String
    let generatedAt: Date
    let plannedTotalMinutes: Int
    let actualTotalMinutes: Int
    let attendance: [TrainingAttendanceEntryDTO]
    let groupFeedback: [TrainingGroupFeedbackDTO]
    let playerNotes: [TrainingPlayerNoteDTO]
    let summary: String
}

struct TrainingExerciseTemplateDTO: Codable {
    let id: String
    let name: String
    let baseDescription: String
    let defaultDuration: Int
    let defaultIntensity: String
    let defaultRequiredPlayers: Int
    let defaultMaterials: [TrainingMaterialQuantityDTO]
}

struct TrainingTemplatesPageDTO: Decodable {
    let items: [TrainingExerciseTemplateDTO]
    let nextCursor: String?
}

struct TrainingLiveDeviationDTO: Codable {
    let id: String
    let planID: String
    let phaseID: String?
    let exerciseID: String?
    let kind: String
    let plannedValue: String
    let actualValue: String
    let note: String
    let timestamp: Date
}

struct TrainingPlanEnvelopeDTO: Decodable {
    let plan: TrainingPlanDTO
    let phases: [TrainingPhaseDTO]
    let exercises: [TrainingExerciseDTO]
    let groups: [TrainingGroupDTO]
    let briefings: [TrainingGroupBriefingDTO]
    let report: TrainingReportDTO?
    let availability: [TrainingAvailabilitySnapshotDTO]
    let deviations: [TrainingLiveDeviationDTO]
}

struct TrainingAvailabilitySnapshotDTO: Codable {
    let playerID: UUID
    let availability: String
    let isAbsent: Bool
    let isLimited: Bool
    let note: String
}

struct CreateTrainingPlanRequest: Encodable {
    let title: String
    let date: Date
    let location: String
    let mainGoal: String
    let secondaryGoals: [String]
    let linkedMatchID: UUID?
}

struct UpdateTrainingPlanRequest: Encodable {
    let title: String
    let date: Date
    let location: String
    let mainGoal: String
    let secondaryGoals: [String]
    let linkedMatchID: UUID?
    let status: String
}

struct SaveTrainingPhasesRequest: Encodable {
    let phases: [TrainingPhaseDTO]
}

struct SaveTrainingExercisesRequest: Encodable {
    let exercises: [TrainingExerciseDTO]
}

struct CreateTrainingTemplateRequest: Encodable {
    let name: String
    let baseDescription: String
    let defaultDuration: Int
    let defaultIntensity: String
    let defaultRequiredPlayers: Int
    let defaultMaterials: [TrainingMaterialQuantityDTO]
}

struct UpsertTrainingGroupRequest: Encodable {
    let id: String?
    let name: String
    let goal: String
    let playerIDs: [UUID]
    let headCoachUserID: String
    let assistantCoachUserID: String?
}

struct SaveTrainingGroupBriefingRequest: Encodable {
    let goal: String
    let coachingPoints: String
    let focusPoints: String
    let commonMistakes: String
    let targetIntensity: String
}

struct AssignTrainingParticipantsRequest: Encodable {
    let availability: [TrainingAvailabilitySnapshotDTO]
}

struct StartTrainingLiveRequest: Encodable {
    let startedAt: Date
}

struct SaveTrainingLiveStateRequest: Encodable {
    let phases: [TrainingPhaseDTO]
    let exercises: [TrainingExerciseDTO]
}

struct CreateTrainingLiveDeviationRequest: Encodable {
    let phaseID: String?
    let exerciseID: String?
    let kind: String
    let plannedValue: String
    let actualValue: String
    let note: String
    let timestamp: Date
}

struct CreateTrainingReportRequest: Encodable {
    let plannedTotalMinutes: Int
    let actualTotalMinutes: Int
    let attendance: [TrainingAttendanceEntryDTO]
    let groupFeedback: [TrainingGroupFeedbackDTO]
    let playerNotes: [TrainingPlayerNoteDTO]
    let summary: String
}

struct LinkTrainingCalendarRequest: Encodable {
    let playersViewLevel: String
}

struct DuplicateTrainingPlanRequest: Encodable {
    let asTemplate: Bool
    let name: String?
    let targetDate: Date?
}

struct EmptyResponse: Decodable {
    init() {}
}

struct TrainingSessionDTO: Decodable {
    let title: String
    let date: Date
    let focus: String
}

struct MatchInfoDTO: Decodable {
    let opponent: String
    let date: Date
    let homeAway: String
}

struct MessageThreadDTO: Decodable {
    let title: String
    let lastMessage: String
    let unreadCount: Int
}

struct FeedbackEntryDTO: Decodable {
    let player: String
    let summary: String
    let date: Date
}

struct TransactionEntryDTO: Decodable {
    let title: String
    let amount: Double
    let date: Date
    let type: String
}

struct CashBootstrapDTO: Decodable {
    let categories: [CashCategoryDTO]
    let transactions: [CashTransactionDTO]
    let contributions: [MonthlyContributionDTO]
    let goals: [CashGoalDTO]
}

struct CashTransactionsPageDTO: Decodable {
    let items: [CashTransactionDTO]
    let nextCursor: String?
}

struct CashCategoryDTO: Codable {
    let id: String
    let name: String
    let colorHex: String
    let isDefault: Bool
}

struct CashTransactionDTO: Codable {
    let id: String
    let amount: Double
    let date: Date
    let categoryID: String
    let description: String
    let type: String
    let playerID: UUID?
    let responsibleTrainerID: String?
    let comment: String
    let paymentStatus: String
    let contextLabel: String?
    let createdAt: Date
    let updatedAt: Date
}

struct UpsertCashTransactionRequest: Encodable {
    let amount: Double
    let date: Date
    let categoryID: String
    let description: String
    let type: String
    let playerID: UUID?
    let responsibleTrainerID: String?
    let comment: String
    let paymentStatus: String
    let contextLabel: String?
}

struct MonthlyContributionDTO: Codable {
    let id: String
    let playerID: UUID
    let amount: Double
    let dueDate: Date
    let status: String
    let monthKey: String
    let lastReminderAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

struct UpsertMonthlyContributionRequest: Encodable {
    let playerID: UUID
    let amount: Double
    let dueDate: Date
    let status: String
    let monthKey: String
}

struct SendCashReminderRequest: Encodable {
    let contributionIDs: [String]
}

struct CashGoalDTO: Codable {
    let id: String
    let name: String
    let targetAmount: Double
    let currentProgress: Double
    let startDate: Date
    let endDate: Date
    let createdAt: Date
    let updatedAt: Date
}

struct UpsertCashGoalRequest: Encodable {
    let name: String
    let targetAmount: Double
    let currentProgress: Double
    let startDate: Date
    let endDate: Date
}

struct FileItemDTO: Decodable {
    let name: String
    let category: String
}

struct TeamStorageUsageDTO: Decodable {
    let teamID: String
    let quotaBytes: Int64
    let usedBytes: Int64
    let updatedAt: Date
}

struct CloudFolderDTO: Decodable {
    let id: String
    let teamID: String
    let parentID: String?
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let isSystemFolder: Bool
    let isDeleted: Bool
}

struct CloudFileDTO: Decodable {
    let id: String
    let teamID: String
    let ownerUserID: String
    let name: String
    let originalName: String
    let type: String
    let mimeType: String
    let sizeBytes: Int64
    let createdAt: Date
    let updatedAt: Date
    let folderID: String?
    let tags: [String]
    let moduleHint: String?
    let visibility: String?
    let sharedUserIDs: [String]?
    let checksum: String?
    let uploadStatus: String?
    let deletedAt: Date?
    let linkedAnalysisSessionID: String?
    let linkedAnalysisClipID: String?
    let linkedTacticsScenarioID: String?
    let linkedTrainingPlanID: String?
}

struct CloudFilesPageDTO: Decodable {
    let items: [CloudFileDTO]
    let nextCursor: String?
}

struct CloudFilesBootstrapDTO: Decodable {
    let teamID: String
    let usage: TeamStorageUsageDTO
    let folders: [CloudFolderDTO]
    let files: [CloudFileDTO]
    let nextCursor: String?
}

struct CloudFilesQueryRequest: Equatable {
    let teamID: String
    let status: String
    let cursor: String?
    let limit: Int
    let query: String?
    let type: String?
    let folderID: String?
    let ownerUserID: String?
    let from: Date?
    let to: Date?
    let minSizeBytes: Int64?
    let maxSizeBytes: Int64?
    let sortField: String
    let sortDirection: String
}

struct CreateCloudFolderRequest: Encodable {
    let teamID: String
    let parentFolderID: String?
    let name: String
}

struct UpdateCloudFolderRequest: Encodable {
    let name: String?
    let parentFolderID: String?
}

struct RegisterCloudFileUploadRequest: Encodable {
    let teamID: String
    let folderID: String?
    let name: String
    let originalName: String
    let type: String
    let mimeType: String
    let sizeBytes: Int64
    let moduleHint: String
    let visibility: String
    let tags: [String]
    let checksum: String
    let linkedAnalysisSessionID: String?
    let linkedAnalysisClipID: String?
    let linkedTacticsScenarioID: String?
    let linkedTrainingPlanID: String?
}

struct RegisterCloudFileUploadResponse: Decodable {
    let fileID: String
    let uploadID: String
    let uploadURL: String
    let uploadHeaders: [String: String]
    let chunkSizeBytes: Int
    let totalParts: Int
    let expiresAt: Date?
}

struct CloudUploadChunkDigestRequest: Encodable {
    let partNumber: Int
    let etag: String
    let sizeBytes: Int64
}

struct CompleteCloudFileUploadRequest: Encodable {
    let uploadID: String
    let fileSize: Int64
    let sha256: String
    let chunks: [CloudUploadChunkDigestRequest]
}

struct UpdateCloudFileRequest: Encodable {
    let name: String?
    let tags: [String]?
    let visibility: String?
    let sharedUserIDs: [String]?
    let moduleHint: String?
    let linkedAnalysisSessionID: String?
    let linkedAnalysisClipID: String?
    let linkedTacticsScenarioID: String?
    let linkedTrainingPlanID: String?
}

struct MoveCloudFileRequest: Encodable {
    let folderID: String?
}

struct TrashCloudFileRequest: Encodable {
    let deletedAt: Date
}

struct RestoreCloudFileRequest: Encodable {
    let folderID: String?
}

struct TacticBoardDTO: Decodable {
    let title: String
    let detail: String
}

struct LegacyAnalysisClipDTO: Decodable {
    let title: String
    let tags: [String]
}

struct AdminTaskDTO: Decodable {
    let title: String
    let due: String
}

struct AdminBootstrapDTO: Decodable {
    let persons: [AdminPersonDTO]
    let groups: [AdminGroupDTO]
    let invitations: [AdminInvitationDTO]
    let auditEntries: [AdminAuditEntryDTO]
    let seasons: [AdminSeasonDTO]
    let activeSeasonID: String?
    let clubSettings: AdminClubSettingsDTO
    let messengerRules: AdminMessengerRulesDTO
}

struct AdminPersonDTO: Codable {
    let id: String
    let fullName: String
    let email: String
    let personType: String
    let role: String?
    let teamName: String
    let groupIDs: [String]
    let permissions: [String]
    let presenceStatus: String
    let isOnline: Bool
    let linkedPlayerID: UUID?
    let linkedMessengerUserID: String?
    let lastActiveAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

struct AdminGroupDTO: Codable {
    let id: String
    let name: String
    let goal: String
    let groupType: String
    let memberIDs: [String]
    let responsibleCoachID: String?
    let assistantCoachID: String?
    let startsAt: Date?
    let endsAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

struct AdminInvitationDTO: Codable {
    let id: String
    let recipientName: String
    let email: String
    let method: String
    let role: String
    let teamName: String
    let status: String
    let inviteLink: String?
    let sentBy: String
    let sentAt: Date
    let expiresAt: Date
    let updatedAt: Date
}

struct AdminAuditEntryDTO: Codable {
    let id: String
    let actorName: String
    let targetName: String
    let area: String
    let action: String
    let details: String
    let timestamp: Date
}

struct AdminAuditEntriesPageDTO: Decodable {
    let items: [AdminAuditEntryDTO]
    let nextCursor: String?
}

struct AdminSeasonDTO: Codable {
    let id: String
    let name: String
    let startsAt: Date
    let endsAt: Date
    let status: String
    let teamCount: Int
    let playerCount: Int
    let trainerCount: Int
    let createdAt: Date
    let updatedAt: Date
}

struct AdminClubSettingsDTO: Codable {
    let id: String?
    let clubName: String
    let clubLogoPath: String
    let primaryColorHex: String
    let secondaryColorHex: String
    let standardTrainingTypes: [String]
    let defaultVisibility: String
    let teamNameConvention: String
    let globalPermissions: [String]
}

struct AdminMessengerRulesDTO: Codable {
    let id: String?
    let allowPrivatePlayerChat: Bool
    let allowDirectTrainerPlayerChat: Bool
    let defaultReadOnlyForPlayers: Bool
    let defaultGroups: [String]
    let allowedChatTypes: [String]
    let groupRuleDescription: String
}

struct UpsertAdminPersonRequest: Encodable {
    let id: String?
    let fullName: String
    let email: String
    let personType: String
    let role: String?
    let teamName: String
    let groupIDs: [String]
    let permissions: [String]
    let presenceStatus: String
    let linkedPlayerID: UUID?
}

struct UpsertAdminGroupRequest: Encodable {
    let id: String?
    let name: String
    let goal: String
    let groupType: String
    let memberIDs: [String]
    let responsibleCoachID: String?
    let assistantCoachID: String?
    let startsAt: Date?
    let endsAt: Date?
}

struct CreateAdminInvitationRequest: Encodable {
    let recipientName: String
    let email: String
    let method: String
    let role: String
    let teamName: String
    let expiresAt: Date
}

struct UpdateAdminInvitationStatusRequest: Encodable {
    let status: String
}

struct UpsertAdminSeasonRequest: Encodable {
    let id: String?
    let name: String
    let startsAt: Date
    let endsAt: Date
    let status: String
}

struct UpdateAdminSeasonStatusRequest: Encodable {
    let status: String
}

struct DuplicateSeasonRosterRequest: Encodable {
    let sourceSeasonID: String
}

struct SetActiveSeasonRequest: Encodable {
    let seasonID: String
}

struct UpsertAdminClubSettingsRequest: Encodable {
    let clubName: String
    let clubLogoPath: String
    let primaryColorHex: String
    let secondaryColorHex: String
    let standardTrainingTypes: [String]
    let defaultVisibility: String
    let teamNameConvention: String
    let globalPermissions: [String]
}

struct UpsertAdminMessengerRulesRequest: Encodable {
    let allowPrivatePlayerChat: Bool
    let allowDirectTrainerPlayerChat: Bool
    let defaultReadOnlyForPlayers: Bool
    let defaultGroups: [String]
    let allowedChatTypes: [String]
    let groupRuleDescription: String
}

struct SettingsBootstrapDTO: Decodable {
    let presentation: PresentationSettingsDTO
    let notifications: NotificationSettingsDTO
    let security: SecuritySettingsDTO
    let appInfo: AppInfoSettingsDTO
    let account: AccountSettingsDTO
}

struct PresentationSettingsDTO: Codable {
    let language: String
    let region: String
    let timeZoneID: String
    let unitSystem: String
    let appearanceMode: String
    let contrastMode: String
    let uiScale: String
    let reduceAnimations: Bool
    let interactivePreviews: Bool
}

struct ModuleNotificationSettingsDTO: Codable {
    let module: String
    let push: Bool
    let inApp: Bool
    let email: Bool
}

struct NotificationSettingsDTO: Codable {
    let globalEnabled: Bool
    let modules: [ModuleNotificationSettingsDTO]
}

struct SecuritySessionDTO: Codable {
    let id: String
    let deviceName: String
    let platformName: String
    let lastUsedAt: Date
    let ipAddress: String
    let location: String
    let isCurrentDevice: Bool
}

struct SecurityTokenDTO: Codable {
    let id: String
    let name: String
    let scope: String
    let lastUsedAt: Date?
    let createdAt: Date
}

struct SecuritySettingsDTO: Codable {
    let twoFactorEnabled: Bool
    let sessions: [SecuritySessionDTO]
    let apiTokens: [SecurityTokenDTO]
    let privacyURL: String
}

struct AppInfoSettingsDTO: Codable {
    let version: String
    let buildNumber: String
    let lastUpdateAt: Date
    let updateState: String
    let changelog: [String]
}

struct AccountContextDTO: Codable {
    let id: String
    let clubName: String
    let teamName: String
    let roleTitle: String
    let isCurrent: Bool
}

struct AccountSettingsDTO: Codable {
    let contexts: [AccountContextDTO]
    let selectedContextID: String?
    let canDeactivateAccount: Bool
    let canLeaveTeam: Bool
}

struct SavePresentationSettingsRequest: Encodable {
    let language: String
    let region: String
    let timeZoneID: String
    let unitSystem: String
    let appearanceMode: String
    let contrastMode: String
    let uiScale: String
    let reduceAnimations: Bool
    let interactivePreviews: Bool
}

struct SaveNotificationSettingsRequest: Encodable {
    let globalEnabled: Bool
    let modules: [ModuleNotificationSettingsDTO]
}

struct ChangePasswordRequest: Encodable {
    let currentPassword: String
    let newPassword: String
}

struct UpdateTwoFactorRequest: Encodable {
    let enabled: Bool
}

struct RevokeSessionRequest: Encodable {
    let sessionID: String
}

struct SubmitSettingsFeedbackRequest: Encodable {
    let category: String
    let message: String
    let screenshotPath: String?
    let appVersion: String
    let buildNumber: String
    let deviceModel: String
    let platform: String
    let activeModuleID: String
}

struct SwitchAccountContextRequest: Encodable {
    let contextID: String
}

private extension AvailabilityStatus {
    var backendValue: String {
        switch self {
        case .fit:
            return "fit"
        case .limited:
            return "limited"
        case .unavailable:
            return "unavailable"
        }
    }
}

private extension PreferredFoot {
    var backendValue: String {
        switch self {
        case .left:
            return "left"
        case .right:
            return "right"
        case .both:
            return "both"
        }
    }
}

private extension SquadStatus {
    var backendValue: String {
        switch self {
        case .active:
            return "active"
        case .prospect:
            return "prospect"
        case .rehab:
            return "rehab"
        }
    }
}
