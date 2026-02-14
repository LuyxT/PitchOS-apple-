import Foundation
import Combine

enum BackendConnectionState: Equatable {
    case placeholder
    case syncing
    case live
    case failed(String)
}

enum AnalysisStoreError: LocalizedError {
    case emptyTitle
    case sessionNotFound
    case videoAssetNotFound
    case backendIdentifierMissing
    case invalidClipRange
    case clipNameRequired
    case clipNotFound

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Bitte einen Titel für die Analyse eingeben."
        case .sessionNotFound:
            return "Analyse-Sitzung nicht gefunden."
        case .videoAssetNotFound:
            return "Video-Asset nicht gefunden."
        case .backendIdentifierMissing:
            return "Server-ID für diese Aktion fehlt."
        case .invalidClipRange:
            return "Clip-Ende muss nach dem Start liegen."
        case .clipNameRequired:
            return "Clip-Name ist erforderlich."
        case .clipNotFound:
            return "Clip nicht gefunden."
        }
    }
}

enum BootstrapCheckError: LocalizedError, Equatable {
    case timeout

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Timeout beim Backend-Check"
        }
    }
}

@MainActor
final class AppDataStore: ObservableObject {
    let backend: BackendRepository
    let cloudFileStore: CloudFileStore
    let cloudFileSyncService: CloudFileSyncService
    let fileOpenRouter: FileOpenRouter
    let analysisVideoStore: AnalysisVideoStore
    let analysisPlaybackService: AnalysisPlaybackService
    let analysisSyncService: AnalysisSyncService
    let messengerSyncService: MessengerSyncService
    let messengerOutboxStore: MessengerOutboxStore
    let messengerMediaStore: MessengerMediaStore
    let messengerSearchService = MessengerSearchService()
    let messengerRealtimeService: MessengerRealtimeService
    var tacticsSyncTask: Task<Void, Never>?
    var messengerOutboxRetryTask: Task<Void, Never>?
    var messengerRealtimeReconnectTask: Task<Void, Never>?
    var messengerOutboxItems: [MessengerOutboxItem] = []
    var messengerRealtimeCursor: String?
    var messengerReconnectAttempt = 0

    @Published var backendConnectionState: BackendConnectionState = .syncing

    @Published var profile: CoachProfile = CoachProfile(
        name: "",
        license: "",
        team: "",
        seasonGoal: ""
    )
    @Published var personProfiles: [PersonProfile] = []
    @Published var profileAuditEntries: [ProfileAuditEntry] = []
    @Published var activePersonProfileID: UUID?
    @Published var profileConnectionState: BackendConnectionState = .syncing
    @Published var settingsPresentation: AppPresentationSettings = .default
    @Published var settingsNotifications: NotificationSettingsState = .default
    @Published var settingsSecurity: SecuritySettingsState = .default
    @Published var settingsAppInfo: AppInfoState = .default
    @Published var settingsAccount: AccountSettingsState = .default
    @Published var settingsConnectionState: BackendConnectionState = .syncing
    @Published var settingsLastErrorMessage: String?
    @Published var cloudFolders: [CloudFolder] = []
    @Published var cloudFiles: [CloudFile] = []
    @Published var cloudUsage: TeamStorageUsage = .default
    @Published var cloudUploads: [CloudUploadProgress] = []
    @Published var cloudFileNextCursor: String?
    @Published var cloudConnectionState: BackendConnectionState = .syncing
    @Published var cloudLastErrorMessage: String?
    @Published var cloudLargestFiles: [CloudFile] = []
    @Published var cloudOldFiles: [CloudFile] = []
    @Published var selectedCloudFileID: UUID?
    @Published var cloudActiveFolderID: UUID?

    @Published var players: [Player] = []
    @Published var calendarCategories: [CalendarCategory] = [CalendarCategory.training, CalendarCategory.match]
    @Published var calendarEvents: [CalendarEvent] = []
    @Published var trainings: [TrainingSession] = []

    @Published var trainingPlans: [TrainingPlan] = []
    @Published var trainingPhasesByPlan: [UUID: [TrainingPhase]] = [:]
    @Published var trainingExercisesByPhase: [UUID: [TrainingExercise]] = [:]
    @Published var trainingGroupsByPlan: [UUID: [TrainingGroup]] = [:]
    @Published var trainingBriefingsByGroup: [UUID: TrainingGroupBriefing] = [:]
    @Published var trainingReportsByPlan: [UUID: TrainingReport] = [:]
    @Published var trainingTemplates: [TrainingExerciseTemplate] = []
    @Published var trainingAvailabilityByPlan: [UUID: [TrainingAvailabilitySnapshot]] = [:]
    @Published var trainingDeviationsByPlan: [UUID: [TrainingLiveDeviation]] = [:]
    @Published var activeTrainingPlanID: UUID?
    @Published var trainingConnectionState: BackendConnectionState = .syncing
    @Published var trainingFilterAssignedCoachID: String?

    @Published var matches: [MatchInfo] = []
    @Published var threads: [MessageThread] = []

    @Published var messengerCurrentUser: MessengerCurrentUser?
    @Published var messengerUserDirectory: [MessengerParticipant] = []
    @Published var messengerChats: [MessengerChat] = []
    @Published var messengerArchivedChats: [MessengerChat] = []
    @Published var messengerMessagesByChat: [UUID: [MessengerMessage]] = [:]
    @Published var messengerSearchResults: [MessengerSearchResult] = []
    @Published var messengerConnectionState: MessengerConnectionState = .disconnected
    @Published var messengerOutboxCount: Int = 0
    @Published var messengerChatNextCursor: String?
    @Published var messengerMessageNextCursorByChat: [UUID: String] = [:]

    @Published var feedbackEntries: [FeedbackEntry] = []
    @Published var transactions: [TransactionEntry] = []
    @Published var cashTransactions: [CashTransaction] = []
    @Published var cashCategories: [CashCategory] = []
    @Published var cashMonthlyContributions: [MonthlyContribution] = []
    @Published var cashGoals: [CashGoal] = []
    @Published var cashConnectionState: BackendConnectionState = .syncing
    @Published var cashTransactionsNextCursor: String?
    @Published var cashLastErrorMessage: String?
    @Published var cashAccessContext: CashAccessContext = CashAccessContext(
        role: .trainer,
        permissions: Set(CashPermission.allCases),
        currentPlayerID: nil
    )

    @Published var files: [FileItem] = []
    @Published var tactics: [TacticBoard] = []
    @Published var tacticsScenarios: [TacticsScenario] = []
    @Published var tacticsBoardStates: [UUID: TacticsBoardState] = [:]
    @Published var activeTacticsScenarioID: UUID?

    @Published var analysisVideoAssets: [AnalysisVideoAsset] = []
    @Published var analysisSessions: [AnalysisSession] = []
    @Published var analysisMarkers: [AnalysisMarker] = []
    @Published var analysisClips: [AnalysisClip] = []
    @Published var analysisDrawings: [AnalysisDrawing] = []
    @Published var analysisCategories: [AnalysisMarkerCategory] = AnalysisMarkerCategory.default
    @Published var activeAnalysisSessionID: UUID?
    @Published var sharedClipReferences: [SharedClipReference] = []

    @Published var adminTasks: [AdminTask] = []
    @Published var adminPersons: [AdminPerson] = []
    @Published var adminGroups: [AdminGroup] = []
    @Published var adminInvitations: [AdminInvitation] = []
    @Published var adminAuditEntries: [AdminAuditEntry] = []
    @Published var adminSeasons: [AdminSeason] = []
    @Published var activeAdminSeasonID: UUID?
    @Published var adminClubSettings: AdminClubSettings = .default
    @Published var adminMessengerRules: AdminMessengerRules = .default
    @Published var adminConnectionState: BackendConnectionState = .syncing

    init() {
        let client = APIClient()
        let auth = AuthService(client: client)
        backend = BackendRepository(client: client, auth: auth)
        cloudFileStore = CloudFileStore()
        cloudFileSyncService = CloudFileSyncService(backend: backend)
        fileOpenRouter = FileOpenRouter()
        analysisVideoStore = AnalysisVideoStore()
        analysisPlaybackService = AnalysisPlaybackService()
        analysisSyncService = AnalysisSyncService(backend: backend)
        messengerSyncService = MessengerSyncService(backend: backend)
        messengerOutboxStore = MessengerOutboxStore()
        messengerMediaStore = MessengerMediaStore()
        messengerRealtimeService = MessengerRealtimeService()
        configureMessengerRealtimeCallbacks()
        clearSeededDataForBackendOnlyMode()
        loadPersistedVideoAssets()
    }

    // MARK: - Video asset persistence

    private var videoAssetsFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("PitchInsights", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path(percentEncoded: false)) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("analysis_video_assets.json")
    }

    private func loadPersistedVideoAssets() {
        let url = videoAssetsFileURL
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)),
              let data = try? Data(contentsOf: url),
              let assets = try? JSONDecoder().decode([AnalysisVideoAsset].self, from: data) else {
            return
        }
        analysisVideoAssets = assets
        print("[Analysis] Loaded \(assets.count) persisted video assets from disk")
    }

    private func persistVideoAssets() {
        guard let data = try? JSONEncoder().encode(analysisVideoAssets) else { return }
        try? data.write(to: videoAssetsFileURL, options: .atomic)
    }

    func refreshFromBackend() async {
        backendConnectionState = .syncing

        // Verify auth is valid with a lightweight call first.
        do {
            _ = try await backend.fetchAuthMe()
        } catch {
            if let networkErr = error as? NetworkError, networkErr.isUnauthorized {
                print("[client] refreshFromBackend: unauthorized — clearing session")
                backendConnectionState = .failed("Sitzung abgelaufen. Bitte erneut anmelden.")
                backend.auth.clearTokens(notify: true)
                return
            } else if isConnectivityFailure(error) {
                print("[client] refreshFromBackend: connectivity failure")
                backendConnectionState = .failed("Keine Verbindung zum Server.")
            } else {
                print("[client] refreshFromBackend: auth check failed, continuing anyway — \(error.localizedDescription)")
            }
            if backendConnectionState != .syncing { return }
        }

        // Fetch all data sources independently — missing endpoints (404) are tolerated.
        let profileDTO = try? await backend.fetchProfile()
        let playersDTO = try? await backend.fetchPlayers()
        let calendarEventsDTO = try? await backend.fetchCalendarEvents()
        let calendarCategoriesDTO = try? await backend.fetchCalendarCategories()
        let trainingsDTO = try? await backend.fetchTrainings()
        let matchesDTO = try? await backend.fetchMatches()
        let threadsDTO = try? await backend.fetchThreads()
        let feedbackDTO = try? await backend.fetchFeedback()
        let transactionsDTO = try? await backend.fetchTransactions()
        let filesDTO = try? await backend.fetchFiles()
        let tacticsDTO = try? await backend.fetchTactics()
        let adminDTO = try? await backend.fetchAdminTasks()
        let tacticsStateDTO = try? await backend.fetchTacticsState()
        let analysisSessionsDTO = try? await backend.fetchAnalysisSessions()
        let profilesDTO = try? await backend.fetchPersonProfiles()
        let profileAuditDTO = try? await backend.fetchProfileAudit(profileID: nil)
        let cloudBootstrapDTO = try? await backend.fetchCloudFilesBootstrap(teamID: activeCloudTeamID())

        // Apply whatever data we received.
        if let profileDTO {
            profile = CoachProfile(
                name: profileDTO.name,
                license: profileDTO.license,
                team: profileDTO.team,
                seasonGoal: profileDTO.seasonGoal
            )
        }
        if let playersDTO {
            players = playersDTO.map { mapPlayer(from: $0) }
            normalizeTacticsBoardStates()
        }
        if let calendarCategoriesDTO {
            calendarCategories = calendarCategoriesDTO.map {
                CalendarCategory(
                    id: $0.id,
                    name: $0.name,
                    colorHex: $0.colorHex,
                    isSystem: $0.isSystem
                )
            }
            ensureDefaultCategories()
        }
        if let calendarEventsDTO {
            calendarEvents = calendarEventsDTO.map {
                CalendarEvent(
                    id: $0.id,
                    title: $0.title,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    categoryID: $0.categoryId,
                    visibility: CalendarVisibility(rawValue: $0.visibility) ?? .team,
                    audience: CalendarAudience(rawValue: $0.audience) ?? .team,
                    audiencePlayerIDs: $0.audiencePlayerIds?.compactMap { UUID(uuidString: $0) } ?? [],
                    recurrence: CalendarRecurrence(rawValue: $0.recurrence) ?? .none,
                    location: $0.location ?? "",
                    notes: $0.notes ?? "",
                    linkedTrainingPlanID: $0.linkedTrainingPlanID.flatMap { UUID(uuidString: $0) },
                    eventKind: CalendarEventKind(rawValue: $0.eventKind ?? "") ?? .generic,
                    playerVisibleGoal: $0.playerVisibleGoal,
                    playerVisibleDurationMinutes: $0.playerVisibleDurationMinutes
                )
            }
        }
        if let trainingsDTO {
            trainings = trainingsDTO.map { TrainingSession(title: $0.title, date: $0.date, focus: $0.focus) }
        }
        if let matchesDTO {
            matches = matchesDTO.map { MatchInfo(opponent: $0.opponent, date: $0.date, homeAway: $0.homeAway) }
        }
        if let threadsDTO {
            threads = threadsDTO.map {
                MessageThread(title: $0.title, lastMessage: $0.lastMessage, unreadCount: $0.unreadCount)
            }
        }
        if let feedbackDTO {
            feedbackEntries = feedbackDTO.map { FeedbackEntry(player: $0.player, summary: $0.summary, date: $0.date) }
        }
        if let transactionsDTO {
            transactions = transactionsDTO.map { TransactionEntry(title: $0.title, amount: $0.amount, date: $0.date, type: $0.type == "income" ? .income : .expense) }
            reconcileCashTransactionsFromLegacy(transactionsDTO)
        }
        if let cloudBootstrapDTO {
            applyCloudBootstrap(cloudBootstrapDTO)
            cloudConnectionState = .live
            syncLegacyFilesList()
        } else if let filesDTO {
            files = filesDTO.map { FileItem(name: $0.name, category: $0.category) }
        }
        if let tacticsDTO {
            tactics = tacticsDTO.map { TacticBoard(title: $0.title, detail: $0.detail) }
        }
        if let analysisSessionsDTO {
            mergeAnalysisSessions(analysisSessionsDTO)
        }
        if let adminDTO {
            adminTasks = adminDTO.map { AdminTask(title: $0.title, due: $0.due) }
        }
        if let tacticsStateDTO {
            applyTacticsState(tacticsStateDTO)
        }
        if let profilesDTO {
            personProfiles = profilesDTO.map { mapPersonProfile($0) }.sorted { $0.displayName < $1.displayName }
            activePersonProfileID = preferredProfileSelection()?.id
            if let profileAuditDTO {
                profileAuditEntries = profileAuditDTO.map(mapProfileAuditEntry(_:))
            }
        }
        syncLegacyCoachProfileFromProfiles()
        backendConnectionState = .live
    }

    func checkBackendBootstrap() async -> Bool {
        print("[client] bootstrap start — URL: \(AppConfiguration.API_BASE_URL)")

        let maxAttempts = 2
        for attempt in 1...maxAttempts {
            do {
                let response: BackendHealthResponse = try await withBootstrapTimeout(seconds: 10) { [self] in
                    try await self.backend.healthCheck()
                }
                let normalized = response.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if normalized == "ok" {
                    print("[client] bootstrap success")
                    return true
                }
                // Backend responded but status is not "ok" — still reachable (degraded)
                print("[client] bootstrap: status=\(response.status), treating as reachable (degraded)")
                return true
            } catch {
                print("[client] bootstrap attempt \(attempt)/\(maxAttempts) failed: \(error.localizedDescription)")

                // Non-connectivity error means the backend IS reachable — do not block the app
                if !isConnectivityFailure(error) {
                    print("[client] bootstrap: non-connectivity error — backend is reachable")
                    return true
                }

                // Wait before retrying connectivity failures
                if attempt < maxAttempts {
                    print("[client] bootstrap: retrying in 1.5s...")
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                }
            }
        }

        print("[client] bootstrap exhausted retries — backend unreachable")
        backendConnectionState = .failed("Backend nicht erreichbar")
        return false
    }

    private func withBootstrapTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw BootstrapCheckError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    func isConnectivityFailure(_ error: Error) -> Bool {
        NetworkError.isConnectivity(error)
    }

    func refreshCalendar() async {
        do {
            let eventsDTO = try await backend.fetchCalendarEvents()
            let categoriesDTO = try await backend.fetchCalendarCategories()
            calendarCategories = categoriesDTO.map {
                CalendarCategory(id: $0.id, name: $0.name, colorHex: $0.colorHex, isSystem: $0.isSystem)
            }
            ensureDefaultCategories()
            calendarEvents = eventsDTO.map {
                CalendarEvent(
                    id: $0.id,
                    title: $0.title,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    categoryID: $0.categoryId,
                    visibility: CalendarVisibility(rawValue: $0.visibility) ?? .team,
                    audience: CalendarAudience(rawValue: $0.audience) ?? .team,
                    audiencePlayerIDs: $0.audiencePlayerIds?.compactMap { UUID(uuidString: $0) } ?? [],
                    recurrence: CalendarRecurrence(rawValue: $0.recurrence) ?? .none,
                    location: $0.location ?? "",
                    notes: $0.notes ?? "",
                    linkedTrainingPlanID: $0.linkedTrainingPlanID.flatMap { UUID(uuidString: $0) },
                    eventKind: CalendarEventKind(rawValue: $0.eventKind ?? "") ?? .generic,
                    playerVisibleGoal: $0.playerVisibleGoal,
                    playerVisibleDurationMinutes: $0.playerVisibleDurationMinutes
                )
            }
        } catch {
            // Keep local data on failure.
            print("[client] refreshCalendar failed: \(error.localizedDescription)")
            if isConnectivityFailure(error) {
                backendConnectionState = .failed(error.localizedDescription)
            }
        }
    }

    @MainActor
    func createCalendarEvent(_ draft: CalendarEventDraft) async {
        let event = CalendarEvent(
            id: UUID().uuidString.lowercased(),
            title: draft.title,
            startDate: draft.startDate,
            endDate: draft.endDate,
            categoryID: draft.categoryID,
            visibility: draft.visibility,
            audience: draft.audience,
            audiencePlayerIDs: draft.audiencePlayerIDs,
            recurrence: draft.recurrence,
            location: draft.location,
            notes: draft.notes
        )
        do {
            let request = CreateCalendarEventRequest(from: event)
            _ = try await backend.createCalendarEvent(request)
            await refreshCalendar()
        } catch {
            print("[client] createCalendarEvent failed: \(error.localizedDescription)")
            if isConnectivityFailure(error) {
                backendConnectionState = .failed(error.localizedDescription)
            }
        }
    }

    @MainActor
    func updateCalendarEvent(id: String, draft: CalendarEventDraft) async {
        do {
            let request = UpdateCalendarEventRequest(
                title: draft.title,
                startDate: draft.startDate,
                endDate: draft.endDate,
                categoryId: draft.categoryID,
                visibility: draft.visibility.rawValue,
                audience: draft.audience.rawValue,
                audiencePlayerIds: draft.audiencePlayerIDs,
                recurrence: draft.recurrence.rawValue,
                location: draft.location,
                notes: draft.notes,
                linkedTrainingPlanID: nil,
                eventKind: CalendarEventKind.generic.rawValue,
                playerVisibleGoal: nil,
                playerVisibleDurationMinutes: nil
            )
            _ = try await backend.updateCalendarEvent(id: id, request: request)
            await refreshCalendar()
        } catch {
            print("[client] updateCalendarEvent failed: \(error.localizedDescription)")
            if isConnectivityFailure(error) {
                backendConnectionState = .failed(error.localizedDescription)
            }
        }
    }

    @MainActor
    func deleteCalendarEvent(id: String) async {
        do {
            _ = try await backend.deleteCalendarEvent(id: id)
            await refreshCalendar()
        } catch {
            print("[client] deleteCalendarEvent failed: \(error.localizedDescription)")
            if isConnectivityFailure(error) {
                backendConnectionState = .failed(error.localizedDescription)
            }
        }
    }

    @MainActor
    func duplicateCalendarEvent(_ event: CalendarEvent) async {
        let copy = CalendarEvent(
            id: UUID().uuidString.lowercased(),
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            categoryID: event.categoryID,
            visibility: event.visibility,
            audience: event.audience,
            audiencePlayerIDs: event.audiencePlayerIDs,
            recurrence: event.recurrence,
            location: event.location,
            notes: event.notes
        )
        do {
            let request = CreateCalendarEventRequest(from: copy)
            _ = try await backend.createCalendarEvent(request)
            await refreshCalendar()
        } catch {
            print("[client] duplicateCalendarEvent failed: \(error.localizedDescription)")
            if isConnectivityFailure(error) {
                backendConnectionState = .failed(error.localizedDescription)
            }
        }
    }

    func addCalendarCategory(name: String, colorHex: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if calendarCategories.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            return
        }
        let localCategory = CalendarCategory(id: UUID().uuidString.lowercased(), name: trimmed, colorHex: colorHex, isSystem: false)
        calendarCategories.append(localCategory)

        guard !AppConfiguration.isPlaceholder else { return }
        Task {
            do {
                let dto = try await backend.createCalendarCategory(
                    CreateCalendarCategoryRequest(name: trimmed, colorHex: colorHex)
                )
                if let index = calendarCategories.firstIndex(where: { $0.id == localCategory.id }) {
                    calendarCategories[index] = CalendarCategory(id: dto.id, name: dto.name, colorHex: dto.colorHex, isSystem: dto.isSystem)
                }
            } catch {
                print("[client] addCalendarCategory backend sync failed: \(error.localizedDescription)")
            }
        }
    }

    private func ensureDefaultCategories() {
        if !calendarCategories.contains(where: { $0.name.lowercased() == "training" }) {
            calendarCategories.insert(CalendarCategory.training, at: 0)
        }
        if !calendarCategories.contains(where: { $0.name.lowercased() == "spiel" }) {
            calendarCategories.insert(CalendarCategory.match, at: min(1, calendarCategories.count))
        }
    }

    func createAnalysisFromImportedVideo(
        sourceURL: URL,
        title: String,
        matchID: UUID? = nil,
        teamID: String? = nil,
        cloudFileID: UUID? = nil
    ) async throws -> AnalysisSession {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw AnalysisStoreError.emptyTitle
        }

        let cloudFile: CloudFile
        if let cloudFileID,
           let existing = cloudFiles.first(where: { $0.id == cloudFileID }) {
            cloudFile = existing
        } else {
            cloudFile = try await uploadCloudFile(
                from: sourceURL,
                preferredType: .video,
                moduleHint: .analysis,
                folderID: resolveDefaultFolderID(for: .video),
                tags: ["analyse"],
                visibility: .teamWide
            )
        }
        let persistedVideo = try analysisVideoStore.persistImportedVideo(from: sourceURL)
        var videoAsset = AnalysisVideoAsset(
            cloudFileID: cloudFile.id,
            originalFilename: persistedVideo.originalFilename,
            localRelativePath: persistedVideo.localRelativePath,
            fileSize: persistedVideo.fileSize,
            mimeType: persistedVideo.mimeType,
            sha256: persistedVideo.sha256,
            syncState: .pending
        )

        do {
            let registerResponse = try await analysisSyncService.registerUploadAndCompleteVideo(persistedVideo)
            videoAsset.backendVideoID = registerResponse.videoID
            videoAsset.uploadedAt = Date()
            videoAsset.syncState = AnalysisSyncState.synced
        } catch {
            throw error
        }

        var session = AnalysisSession(
            videoAssetID: videoAsset.id,
            title: trimmedTitle,
            matchID: matchID,
            teamID: teamID,
            syncState: .pending
        )

        do {
            guard let backendVideoID = videoAsset.backendVideoID else {
                throw AnalysisStoreError.backendIdentifierMissing
            }
            let dto = try await analysisSyncService.createSession(
                CreateAnalysisSessionRequest(
                    videoID: backendVideoID,
                    title: trimmedTitle,
                    matchID: matchID,
                    teamID: teamID
                )
                )
            session.backendSessionID = dto.id
            session.createdAt = dto.createdAt
            session.updatedAt = dto.updatedAt
            session.syncState = AnalysisSyncState.synced
        } catch {
            throw error
        }

        analysisVideoAssets.append(videoAsset)
        persistVideoAssets()
        analysisSessions.append(session)
        activeAnalysisSessionID = session.id
        try? await attachAnalysisSession(session.id, toCloudFileID: cloudFile.id)
        return session
    }

    func loadAnalysisSession(_ sessionID: UUID) async throws -> AnalysisSessionBundle {
        guard let sessionIndex = analysisSessions.firstIndex(where: { $0.id == sessionID }) else {
            throw AnalysisStoreError.sessionNotFound
        }

        activeAnalysisSessionID = sessionID
        var session = analysisSessions[sessionIndex]

        if !AppConfiguration.isPlaceholder, let backendSessionID = session.backendSessionID {
            let envelope = try await analysisSyncService.fetchSession(id: backendSessionID)
            let localVideoID = ensureLocalVideoAsset(
                backendVideoID: envelope.session.videoID,
                fallbackLocalID: session.videoAssetID
            )
            session.videoAssetID = localVideoID
            session.title = envelope.session.title
            session.matchID = envelope.session.matchID
            session.teamID = envelope.session.teamID
            session.createdAt = envelope.session.createdAt
            session.updatedAt = envelope.session.updatedAt
            session.syncState = .synced
            analysisSessions[sessionIndex] = session

            analysisMarkers.removeAll { $0.sessionID == session.id }
            analysisClips.removeAll { $0.sessionID == session.id }
            analysisDrawings.removeAll { $0.sessionID == session.id }

            let mappedMarkers = envelope.markers.map { markerDTO in
                mapAnalysisMarker(from: markerDTO, localSessionID: session.id, localVideoID: localVideoID)
            }
            let mappedClips = envelope.clips.map { clipDTO in
                mapAnalysisClip(from: clipDTO, localSessionID: session.id, localVideoID: localVideoID)
            }
            let mappedDrawings = envelope.drawings.map { drawingDTO in
                mapAnalysisDrawing(from: drawingDTO, localSessionID: session.id)
            }

            analysisMarkers.append(contentsOf: mappedMarkers)
            analysisClips.append(contentsOf: mappedClips)
            analysisDrawings.append(contentsOf: mappedDrawings)
            for clip in mappedClips {
                upsertClipCloudFileReference(clip)
            }
        }

        return try bundleForAnalysisSession(sessionID)
    }

    func addMarker(
        sessionID: UUID,
        timeSeconds: Double,
        categoryID: UUID?,
        comment: String,
        playerID: UUID?
    ) async throws -> AnalysisMarker {
        guard let session = analysisSessions.first(where: { $0.id == sessionID }) else {
            throw AnalysisStoreError.sessionNotFound
        }

        let marker = AnalysisMarker(
            sessionID: sessionID,
            videoAssetID: session.videoAssetID,
            timeSeconds: timeSeconds,
            categoryID: categoryID,
            comment: comment,
            playerID: playerID,
            syncState: AppConfiguration.isPlaceholder ? .synced : .pending
        )
        analysisMarkers.append(marker)

        guard !AppConfiguration.isPlaceholder else {
            return marker
        }

        guard let backendSessionID = session.backendSessionID,
              let backendVideoID = analysisVideoAssets.first(where: { $0.id == session.videoAssetID })?.backendVideoID else {
            markMarkerSyncState(marker.id, state: .syncFailed)
            throw AnalysisStoreError.backendIdentifierMissing
        }

        do {
            let dto = try await analysisSyncService.addMarker(
                CreateAnalysisMarkerRequest(
                    sessionID: backendSessionID,
                    videoID: backendVideoID,
                    timeSeconds: timeSeconds,
                    categoryID: categoryID,
                    comment: comment,
                    playerID: playerID
                )
            )
            let mapped = mapAnalysisMarker(from: dto, localSessionID: sessionID, localVideoID: session.videoAssetID)
            replaceMarker(markerID: marker.id, with: mapped)
            return mapped
        } catch {
            markMarkerSyncState(marker.id, state: .syncFailed)
            throw error
        }
    }

    func updateMarker(
        markerID: UUID,
        categoryID: UUID?,
        comment: String,
        playerID: UUID?
    ) async throws {
        guard let index = analysisMarkers.firstIndex(where: { $0.id == markerID }) else { return }
        analysisMarkers[index].categoryID = categoryID
        analysisMarkers[index].comment = comment
        analysisMarkers[index].playerID = playerID
        analysisMarkers[index].updatedAt = Date()
        analysisMarkers[index].syncState = AppConfiguration.isPlaceholder ? .synced : .pending

        guard !AppConfiguration.isPlaceholder else { return }
        guard let backendID = analysisMarkers[index].backendMarkerID else {
            analysisMarkers[index].syncState = .syncFailed
            throw AnalysisStoreError.backendIdentifierMissing
        }

        do {
            let dto = try await analysisSyncService.updateMarker(
                id: backendID,
                request: UpdateAnalysisMarkerRequest(
                    categoryID: categoryID,
                    comment: comment,
                    playerID: playerID
                )
            )
            analysisMarkers[index] = mapAnalysisMarker(
                from: dto,
                localSessionID: analysisMarkers[index].sessionID,
                localVideoID: analysisMarkers[index].videoAssetID
            )
        } catch {
            analysisMarkers[index].syncState = .syncFailed
            throw error
        }
    }

    func deleteMarker(markerID: UUID) async throws {
        guard let marker = analysisMarkers.first(where: { $0.id == markerID }) else { return }
        analysisMarkers.removeAll { $0.id == markerID }

        guard !AppConfiguration.isPlaceholder else { return }
        if let backendID = marker.backendMarkerID {
            do {
                try await analysisSyncService.deleteMarker(id: backendID)
            } catch {
                throw error
            }
        }
    }

    func createClip(
        sessionID: UUID,
        name: String,
        startSeconds: Double,
        endSeconds: Double,
        playerIDs: [UUID],
        note: String
    ) async throws -> AnalysisClip {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw AnalysisStoreError.clipNameRequired
        }
        guard endSeconds > startSeconds else {
            throw AnalysisStoreError.invalidClipRange
        }
        guard let session = analysisSessions.first(where: { $0.id == sessionID }) else {
            throw AnalysisStoreError.sessionNotFound
        }

        let clip = AnalysisClip(
            sessionID: sessionID,
            videoAssetID: session.videoAssetID,
            name: trimmedName,
            startSeconds: startSeconds,
            endSeconds: endSeconds,
            playerIDs: playerIDs,
            note: note,
            syncState: AppConfiguration.isPlaceholder ? .synced : .pending
        )
        analysisClips.append(clip)

        guard !AppConfiguration.isPlaceholder else {
            upsertClipCloudFileReference(clip)
            return clip
        }

        guard let backendSessionID = session.backendSessionID,
              let backendVideoID = analysisVideoAssets.first(where: { $0.id == session.videoAssetID })?.backendVideoID else {
            markClipSyncState(clip.id, state: .syncFailed)
            throw AnalysisStoreError.backendIdentifierMissing
        }

        do {
            let dto = try await analysisSyncService.createClip(
                CreateAnalysisClipRequest(
                    sessionID: backendSessionID,
                    videoID: backendVideoID,
                    name: trimmedName,
                    startSeconds: startSeconds,
                    endSeconds: endSeconds,
                    playerIDs: playerIDs,
                    note: note
                )
            )
            let mapped = mapAnalysisClip(from: dto, localSessionID: sessionID, localVideoID: session.videoAssetID)
            replaceClip(clipID: clip.id, with: mapped)
            upsertClipCloudFileReference(mapped)
            return mapped
        } catch {
            markClipSyncState(clip.id, state: .syncFailed)
            throw error
        }
    }

    func updateClip(
        clipID: UUID,
        name: String,
        startSeconds: Double,
        endSeconds: Double,
        playerIDs: [UUID],
        note: String
    ) async throws {
        guard endSeconds > startSeconds else {
            throw AnalysisStoreError.invalidClipRange
        }
        guard let index = analysisClips.firstIndex(where: { $0.id == clipID }) else { return }
        analysisClips[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        analysisClips[index].startSeconds = startSeconds
        analysisClips[index].endSeconds = endSeconds
        analysisClips[index].playerIDs = playerIDs
        analysisClips[index].note = note
        analysisClips[index].updatedAt = Date()
        analysisClips[index].syncState = AppConfiguration.isPlaceholder ? .synced : .pending

        guard !AppConfiguration.isPlaceholder else { return }
        guard let backendClipID = analysisClips[index].backendClipID else {
            analysisClips[index].syncState = .syncFailed
            throw AnalysisStoreError.backendIdentifierMissing
        }

        do {
            let dto = try await analysisSyncService.updateClip(
                id: backendClipID,
                request: UpdateAnalysisClipRequest(
                    name: analysisClips[index].name,
                    startSeconds: startSeconds,
                    endSeconds: endSeconds,
                    playerIDs: playerIDs,
                    note: note
                )
            )
            analysisClips[index] = mapAnalysisClip(
                from: dto,
                localSessionID: analysisClips[index].sessionID,
                localVideoID: analysisClips[index].videoAssetID
            )
            upsertClipCloudFileReference(analysisClips[index])
        } catch {
            analysisClips[index].syncState = .syncFailed
            throw error
        }
    }

    func deleteClip(clipID: UUID) async throws {
        guard let clip = analysisClips.first(where: { $0.id == clipID }) else { return }
        analysisClips.removeAll { $0.id == clipID }
        removeClipCloudFileReference(clipID)

        guard !AppConfiguration.isPlaceholder else { return }
        if let backendClipID = clip.backendClipID {
            try await analysisSyncService.deleteClip(id: backendClipID)
        }
    }

    func shareClip(_ request: AnalysisShareRequest) async throws {
        guard let clip = analysisClips.first(where: { $0.id == request.clipID }) else {
            throw AnalysisStoreError.clipNotFound
        }

        var responseThreadID = request.threadID
        var responseMessageIDs: [String] = []

        if !AppConfiguration.isPlaceholder {
            guard let backendClipID = clip.backendClipID else {
                throw AnalysisStoreError.backendIdentifierMissing
            }
            let response = try await analysisSyncService.shareClip(request, backendClipID: backendClipID)
            responseThreadID = response.threadID
            responseMessageIDs = response.messageIDs
        }

        let reference = SharedClipReference(
            clipID: clip.id,
            clipName: clip.name,
            playerIDs: request.playerIDs,
            threadID: responseThreadID,
            message: request.message,
            backendMessageIDs: responseMessageIDs
        )
        sharedClipReferences.insert(reference, at: 0)
    }

    func saveDrawings(sessionID: UUID, drawings: [AnalysisDrawing]) async throws {
        analysisDrawings.removeAll { $0.sessionID == sessionID }
        analysisDrawings.append(contentsOf: drawings)

        guard !AppConfiguration.isPlaceholder else { return }
        guard let session = analysisSessions.first(where: { $0.id == sessionID }),
              let backendSessionID = session.backendSessionID else {
            markDrawingsSyncState(sessionID: sessionID, state: .syncFailed)
            throw AnalysisStoreError.backendIdentifierMissing
        }

        do {
            try await analysisSyncService.saveDrawings(sessionID: backendSessionID, drawings: drawings)
            markDrawingsSyncState(sessionID: sessionID, state: .synced)
        } catch {
            markDrawingsSyncState(sessionID: sessionID, state: .syncFailed)
            throw error
        }
    }

    func playbackURL(for videoAssetID: UUID) async throws -> URL {
        guard let asset = analysisVideoAssets.first(where: { $0.id == videoAssetID }) else {
            throw AnalysisStoreError.videoAssetNotFound
        }
        // Prefer local file when available (server storage is ephemeral)
        if !asset.localRelativePath.isEmpty,
           let localURL = analysisVideoStore.fileURL(for: asset.localRelativePath) {
            let exists = FileManager.default.fileExists(atPath: localURL.path(percentEncoded: false))
            print("[Analysis] playbackURL localPath=\(asset.localRelativePath) resolved=\(localURL.path) exists=\(exists)")
            if exists {
                return localURL
            }
        } else {
            print("[Analysis] playbackURL localRelativePath is empty, falling back to backend. backendVideoID=\(asset.backendVideoID ?? "nil")")
        }
        return try await analysisPlaybackService.resolvedPlaybackURL(for: asset, backend: backend)
    }

    func sessionBundle(for sessionID: UUID) -> AnalysisSessionBundle? {
        try? bundleForAnalysisSession(sessionID)
    }

    func addAnalysisCategory(name: String, colorHex: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard !analysisCategories.contains(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) else {
            return
        }
        let localCategory = AnalysisMarkerCategory(name: trimmedName, colorHex: colorHex, isSystem: false)
        analysisCategories.append(localCategory)

        guard !AppConfiguration.isPlaceholder else { return }
        Task {
            do {
                let dto = try await backend.createAnalysisCategory(
                    CreateAnalysisCategoryRequest(name: trimmedName, colorHex: colorHex)
                )
                if let index = analysisCategories.firstIndex(where: { $0.id == localCategory.id }) {
                    analysisCategories[index] = AnalysisMarkerCategory(
                        id: UUID(uuidString: dto.id) ?? localCategory.id,
                        name: dto.name,
                        colorHex: dto.colorHex,
                        isSystem: dto.isSystem
                    )
                }
            } catch {
                print("[client] addAnalysisCategory backend sync failed: \(error.localizedDescription)")
            }
        }
    }

    private func bundleForAnalysisSession(_ sessionID: UUID) throws -> AnalysisSessionBundle {
        guard let session = analysisSessions.first(where: { $0.id == sessionID }) else {
            throw AnalysisStoreError.sessionNotFound
        }
        return AnalysisSessionBundle(
            session: session,
            markers: analysisMarkers.filter { $0.sessionID == sessionID }.sorted { $0.timeSeconds < $1.timeSeconds },
            clips: analysisClips.filter { $0.sessionID == sessionID }.sorted { $0.startSeconds < $1.startSeconds },
            drawings: analysisDrawings.filter { $0.sessionID == sessionID }.sorted { $0.createdAt < $1.createdAt }
        )
    }

    private func mergeAnalysisSessions(_ dtoList: [AnalysisSessionDTO]) {
        for dto in dtoList {
            let localVideoID = ensureLocalVideoAsset(backendVideoID: dto.videoID)
            let sessionID = analysisSessions.first(where: { $0.backendSessionID == dto.id })?.id ?? UUID()
            let session = AnalysisSession(
                id: sessionID,
                backendSessionID: dto.id,
                videoAssetID: localVideoID,
                title: dto.title,
                matchID: dto.matchID,
                teamID: dto.teamID,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt,
                syncState: .synced
            )
            if let index = analysisSessions.firstIndex(where: { $0.id == session.id }) {
                analysisSessions[index] = session
            } else {
                analysisSessions.append(session)
            }
        }
    }

    private func ensureLocalVideoAsset(backendVideoID: String, fallbackLocalID: UUID? = nil) -> UUID {
        if let index = analysisVideoAssets.firstIndex(where: { $0.backendVideoID == backendVideoID }) {
            return analysisVideoAssets[index].id
        }
        // Check if there's an existing asset by fallback ID that already has the local path
        if let fallbackID = fallbackLocalID,
           let index = analysisVideoAssets.firstIndex(where: { $0.id == fallbackID }) {
            analysisVideoAssets[index].backendVideoID = backendVideoID
            persistVideoAssets()
            return fallbackID
        }
        let id = fallbackLocalID ?? UUID()
        analysisVideoAssets.append(
            AnalysisVideoAsset(
                id: id,
                backendVideoID: backendVideoID,
                originalFilename: "Video \(backendVideoID.prefix(6))",
                localRelativePath: "",
                fileSize: 0,
                mimeType: "video/mp4",
                sha256: "",
                syncState: .synced
            )
        )
        persistVideoAssets()
        return id
    }

    private func mapAnalysisMarker(
        from dto: AnalysisMarkerDTO,
        localSessionID: UUID,
        localVideoID: UUID
    ) -> AnalysisMarker {
        let localID = analysisMarkers.first(where: { $0.backendMarkerID == dto.id })?.id ?? UUID()
        return AnalysisMarker(
            id: localID,
            backendMarkerID: dto.id,
            sessionID: localSessionID,
            videoAssetID: localVideoID,
            timeSeconds: dto.timeSeconds,
            categoryID: dto.categoryID,
            comment: dto.comment,
            playerID: dto.playerID,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            syncState: .synced
        )
    }

    private func mapAnalysisClip(
        from dto: AnalysisClipDTO,
        localSessionID: UUID,
        localVideoID: UUID
    ) -> AnalysisClip {
        let localID = analysisClips.first(where: { $0.backendClipID == dto.id })?.id ?? UUID()
        return AnalysisClip(
            id: localID,
            backendClipID: dto.id,
            sessionID: localSessionID,
            videoAssetID: localVideoID,
            name: dto.name,
            startSeconds: dto.startSeconds,
            endSeconds: dto.endSeconds,
            playerIDs: dto.playerIDs,
            note: dto.note,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            syncState: .synced
        )
    }

    private func mapAnalysisDrawing(from dto: AnalysisDrawingDTO, localSessionID: UUID) -> AnalysisDrawing {
        let tool = AnalysisDrawingTool(rawValue: dto.tool) ?? .line
        let localID = dto.localID
            ?? analysisDrawings.first(where: { $0.backendDrawingID == dto.id })?.id
            ?? UUID()
        return AnalysisDrawing(
            id: localID,
            backendDrawingID: dto.id,
            sessionID: localSessionID,
            timeSeconds: dto.timeSeconds,
            tool: tool,
            points: dto.points.map { AnalysisPoint(x: $0.x, y: $0.y) },
            colorHex: dto.colorHex,
            isTemporary: dto.isTemporary,
            createdAt: dto.createdAt,
            syncState: .synced
        )
    }

    private func replaceMarker(markerID: UUID, with marker: AnalysisMarker) {
        if let index = analysisMarkers.firstIndex(where: { $0.id == markerID }) {
            analysisMarkers[index] = marker
        }
    }

    private func replaceClip(clipID: UUID, with clip: AnalysisClip) {
        if let index = analysisClips.firstIndex(where: { $0.id == clipID }) {
            analysisClips[index] = clip
        }
    }

    private func markMarkerSyncState(_ markerID: UUID, state: AnalysisSyncState) {
        guard let index = analysisMarkers.firstIndex(where: { $0.id == markerID }) else { return }
        analysisMarkers[index].syncState = state
    }

    private func markClipSyncState(_ clipID: UUID, state: AnalysisSyncState) {
        guard let index = analysisClips.firstIndex(where: { $0.id == clipID }) else { return }
        analysisClips[index].syncState = state
    }

    private func markDrawingsSyncState(sessionID: UUID, state: AnalysisSyncState) {
        for index in analysisDrawings.indices where analysisDrawings[index].sessionID == sessionID {
            analysisDrawings[index].syncState = state
        }
    }

    func createPlayerQuick(name: String, number: Int, primaryPosition: PlayerPosition) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, number > 0 else { return }

        let player = Player(
            id: UUID(),
            name: trimmed,
            number: number,
            position: primaryPosition.rawValue,
            status: .fit
        )
        players.append(player)
        syncProfileFromPlayerChange(player)
        appendPlayerToAllBenchIfNeeded(player.id)
        pushCreatePlayer(player)
    }

    func updatePlayer(_ updated: Player) {
        guard let index = players.firstIndex(where: { $0.id == updated.id }) else { return }
        players[index] = updated
        syncProfileFromPlayerChange(updated)
        pushUpdatePlayer(updated)
    }

    func duplicatePlayer(_ source: Player) {
        var copy = source
        copy = Player(
            id: UUID(),
            name: "\(source.name) Kopie",
            number: nextFreeNumber(),
            position: source.primaryPosition.rawValue,
            status: source.availability,
            dateOfBirth: source.dateOfBirth,
            secondaryPositions: source.secondaryPositions,
            heightCm: source.heightCm,
            weightKg: source.weightKg,
            preferredFoot: source.preferredFoot,
            teamName: source.teamName,
            squadStatus: source.squadStatus,
            joinedAt: source.joinedAt,
            roles: source.roles,
            groups: source.groups,
            injuryStatus: source.injuryStatus,
            notes: source.notes,
            developmentGoals: source.developmentGoals
        )
        players.append(copy)
        syncProfileFromPlayerChange(copy)
        appendPlayerToAllBenchIfNeeded(copy.id)
        pushCreatePlayer(copy)
    }

    func deletePlayer(id: UUID) {
        players.removeAll { $0.id == id }
        removeProfileLinkedToPlayer(id)
        removePlayerFromAllBoardStates(id)
        removePlayerFromAnalysisReferences(id)
        pushDeletePlayer(id)
    }

    func deletePlayers(ids: Set<UUID>) {
        players.removeAll { ids.contains($0.id) }
        for id in ids {
            removeProfileLinkedToPlayer(id)
            removePlayerFromAllBoardStates(id)
            removePlayerFromAnalysisReferences(id)
            pushDeletePlayer(id)
        }
    }

    func setAvailability(ids: Set<UUID>, value: AvailabilityStatus) {
        for index in players.indices where ids.contains(players[index].id) {
            players[index].availability = value
            syncProfileFromPlayerChange(players[index])
            pushUpdatePlayer(players[index])
        }
    }

    func player(with id: UUID) -> Player? {
        players.first(where: { $0.id == id })
    }

    private func nextFreeNumber() -> Int {
        let used = Set(players.map { $0.number })
        var candidate = 1
        while used.contains(candidate) {
            candidate += 1
        }
        return candidate
    }

    private func mapPlayer(from dto: PlayerDTO, fallbackID: UUID? = nil) -> Player {
        Player(
            id: dto.id ?? fallbackID ?? UUID(),
            name: dto.name,
            number: dto.number,
            position: dto.position,
            status: AvailabilityStatus.fromBackend(dto.status),
            dateOfBirth: dto.dateOfBirth,
            secondaryPositions: (dto.secondaryPositions ?? []).map(PlayerPosition.from(code:)),
            heightCm: dto.heightCm,
            weightKg: dto.weightKg,
            preferredFoot: preferredFoot(from: dto.preferredFoot),
            teamName: dto.teamName ?? "1. Mannschaft",
            squadStatus: squadStatus(from: dto.squadStatus),
            joinedAt: dto.joinedAt,
            roles: dto.roles ?? [],
            groups: dto.groups ?? [],
            injuryStatus: dto.injuryStatus ?? "",
            notes: dto.notes ?? "",
            developmentGoals: dto.developmentGoals ?? ""
        )
    }

    func preferredFoot(from value: String?) -> PreferredFoot? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return nil
        }
        switch value {
        case "left", "links":
            return .left
        case "right", "rechts":
            return .right
        case "both", "beidfuessig", "beidfüssig", "beidfußig", "beidfüßig":
            return .both
        default:
            return nil
        }
    }

    private func squadStatus(from value: String?) -> SquadStatus {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return .active
        }
        switch value {
        case "active", "aktiv":
            return .active
        case "prospect", "perspektive":
            return .prospect
        case "rehab", "reha":
            return .rehab
        default:
            return .active
        }
    }

    private func pushCreatePlayer(_ player: Player) {
        guard !AppConfiguration.isPlaceholder else { return }
        Task {
            do {
                let dto = try await backend.createPlayer(UpsertPlayerRequest(from: player))
                let backendPlayer = mapPlayer(from: dto, fallbackID: player.id)
                if backendPlayer.id != player.id {
                    replacePlayerIDReferences(oldID: player.id, newID: backendPlayer.id)
                }
                if let index = players.firstIndex(where: { $0.id == player.id || $0.id == backendPlayer.id }) {
                    players[index] = backendPlayer
                } else {
                    players.append(backendPlayer)
                }
                backendConnectionState = .live
            } catch {
                print("[client] pushCreatePlayer failed: \(error.localizedDescription)")
                if isConnectivityFailure(error) {
                    backendConnectionState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func pushUpdatePlayer(_ player: Player) {
        guard !AppConfiguration.isPlaceholder else { return }
        Task {
            do {
                let dto = try await backend.updatePlayer(id: player.id, request: UpsertPlayerRequest(from: player))
                let backendPlayer = mapPlayer(from: dto, fallbackID: player.id)
                if let index = players.firstIndex(where: { $0.id == player.id }) {
                    players[index] = backendPlayer
                }
                backendConnectionState = .live
            } catch {
                print("[client] pushUpdatePlayer failed: \(error.localizedDescription)")
                if isConnectivityFailure(error) {
                    backendConnectionState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func pushDeletePlayer(_ playerID: UUID) {
        guard !AppConfiguration.isPlaceholder else { return }
        Task {
            do {
                _ = try await backend.deletePlayer(id: playerID)
                backendConnectionState = .live
            } catch {
                print("[client] pushDeletePlayer failed: \(error.localizedDescription)")
                if isConnectivityFailure(error) {
                    backendConnectionState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func scheduleTacticsStateSync() {
        guard !AppConfiguration.isPlaceholder else { return }
        let request = SaveTacticsStateRequest(
            activeScenarioID: activeTacticsScenarioID,
            scenarios: tacticsScenarios,
            boards: Array(tacticsBoardStates.values)
        )

        tacticsSyncTask?.cancel()
        tacticsSyncTask = Task {
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                _ = try await backend.saveTacticsState(request)
                backendConnectionState = .live
            } catch is CancellationError {
                // Ignore cancellation because a newer sync has been scheduled.
            } catch {
                print("[client] tacticsStateSync failed: \(error.localizedDescription)")
                if isConnectivityFailure(error) {
                    backendConnectionState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func applyTacticsState(_ dto: TacticsStateDTO) {
        guard !dto.scenarios.isEmpty else { return }
        tacticsScenarios = dto.scenarios
        tacticsBoardStates = Dictionary(uniqueKeysWithValues: dto.boards.map { ($0.scenarioID, $0) })
        activeTacticsScenarioID = dto.activeScenarioID ?? dto.scenarios.first?.id
        normalizeTacticsBoardStates()
    }

    private func replacePlayerIDReferences(oldID: UUID, newID: UUID) {
        for index in calendarEvents.indices {
            calendarEvents[index].audiencePlayerIDs = calendarEvents[index]
                .audiencePlayerIDs
                .map { $0 == oldID ? newID : $0 }
        }

        for index in analysisMarkers.indices where analysisMarkers[index].playerID == oldID {
            analysisMarkers[index].playerID = newID
        }

        for index in analysisClips.indices {
            analysisClips[index].playerIDs = analysisClips[index].playerIDs.map { $0 == oldID ? newID : $0 }
        }

        for index in sharedClipReferences.indices {
            sharedClipReferences[index] = SharedClipReference(
                id: sharedClipReferences[index].id,
                clipID: sharedClipReferences[index].clipID,
                clipName: sharedClipReferences[index].clipName,
                playerIDs: sharedClipReferences[index].playerIDs.map { $0 == oldID ? newID : $0 },
                threadID: sharedClipReferences[index].threadID,
                message: sharedClipReferences[index].message,
                backendMessageIDs: sharedClipReferences[index].backendMessageIDs,
                createdAt: sharedClipReferences[index].createdAt
            )
        }

        for scenario in tacticsScenarios {
            guard var board = tacticsBoardStates[scenario.id] else { continue }
            for placementIndex in board.placements.indices where board.placements[placementIndex].playerID == oldID {
                board.placements[placementIndex].playerID = newID
            }
            board.benchPlayerIDs = board.benchPlayerIDs.map { $0 == oldID ? newID : $0 }
            board.excludedPlayerIDs = board.excludedPlayerIDs.map { $0 == oldID ? newID : $0 }
            tacticsBoardStates[scenario.id] = board
        }
    }

    func ensureDefaultTacticsScenario() {
        if tacticsScenarios.isEmpty {
            let scenario = TacticsScenario(name: "Startelf")
            tacticsScenarios = [scenario]
            tacticsBoardStates[scenario.id] = TacticsBoardState.empty(
                scenarioID: scenario.id,
                playerIDs: players.map { $0.id }
            )
            upsertTacticsScenarioCloudFileReference(scenario)
        }

        if activeTacticsScenarioID == nil {
            activeTacticsScenarioID = tacticsScenarios.first?.id
        }

        if let activeTacticsScenarioID, tacticsBoardStates[activeTacticsScenarioID] == nil {
            tacticsBoardStates[activeTacticsScenarioID] = TacticsBoardState.empty(
                scenarioID: activeTacticsScenarioID,
                playerIDs: players.map { $0.id }
            )
        }
        normalizeTacticsBoardStates()
    }

    @discardableResult
    func createScenario(name: String) -> UUID {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let scenarioName = trimmed.isEmpty ? "Neues Szenario" : trimmed
        let scenario = TacticsScenario(name: scenarioName)
        tacticsScenarios.append(scenario)
        tacticsBoardStates[scenario.id] = TacticsBoardState.empty(
            scenarioID: scenario.id,
            playerIDs: players.map { $0.id }
        )
        activeTacticsScenarioID = scenario.id
        upsertTacticsScenarioCloudFileReference(scenario)
        scheduleTacticsStateSync()
        return scenario.id
    }

    @discardableResult
    func duplicateScenario(id: UUID) -> UUID? {
        guard let scenario = tacticsScenarios.first(where: { $0.id == id }),
              var board = tacticsBoardStates[id] else { return nil }

        var duplicate = scenario
        duplicate.id = UUID()
        duplicate.name = "\(scenario.name) Kopie"
        duplicate.updatedAt = Date()
        board.scenarioID = duplicate.id
        tacticsScenarios.append(duplicate)
        tacticsBoardStates[duplicate.id] = board
        activeTacticsScenarioID = duplicate.id
        upsertTacticsScenarioCloudFileReference(duplicate)
        scheduleTacticsStateSync()
        return duplicate.id
    }

    func renameScenario(id: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = tacticsScenarios.firstIndex(where: { $0.id == id }) else { return }
        tacticsScenarios[index].name = trimmed
        tacticsScenarios[index].updatedAt = Date()
        upsertTacticsScenarioCloudFileReference(tacticsScenarios[index])
        scheduleTacticsStateSync()
    }

    func deleteScenario(id: UUID) {
        guard tacticsScenarios.count > 1 else { return }
        tacticsScenarios.removeAll { $0.id == id }
        tacticsBoardStates.removeValue(forKey: id)
        removeTacticsScenarioCloudFileReference(scenarioID: id)
        if activeTacticsScenarioID == id {
            activeTacticsScenarioID = tacticsScenarios.first?.id
        }
        scheduleTacticsStateSync()
    }

    func saveBoardState(_ board: TacticsBoardState) {
        tacticsBoardStates[board.scenarioID] = board
        if let index = tacticsScenarios.firstIndex(where: { $0.id == board.scenarioID }) {
            tacticsScenarios[index].updatedAt = Date()
        }
        scheduleTacticsStateSync()
    }

    func boardState(for scenarioID: UUID) -> TacticsBoardState {
        if let board = tacticsBoardStates[scenarioID] {
            var normalized = board
            normalized.opponentMarkers = normalizeOpponentMarkers(board.opponentMarkers)
            if normalized == board {
                return board
            }
            tacticsBoardStates[scenarioID] = normalized
            return normalized
        }
        let board = TacticsBoardState.empty(scenarioID: scenarioID, playerIDs: players.map { $0.id })
        tacticsBoardStates[scenarioID] = board
        return board
    }

    func resetScenarioLayout(id: UUID) {
        tacticsBoardStates[id] = TacticsBoardState.empty(scenarioID: id, playerIDs: players.map { $0.id })
        if let index = tacticsScenarios.firstIndex(where: { $0.id == id }) {
            tacticsScenarios[index].updatedAt = Date()
        }
        scheduleTacticsStateSync()
    }

    private func normalizeTacticsBoardStates() {
        let validPlayerIDs = Set(players.map { $0.id })

        for scenario in tacticsScenarios {
            var board = tacticsBoardStates[scenario.id]
                ?? TacticsBoardState.empty(scenarioID: scenario.id, playerIDs: players.map { $0.id })

            board.placements.removeAll { !validPlayerIDs.contains($0.playerID) }
            board.benchPlayerIDs = board.benchPlayerIDs.filter { validPlayerIDs.contains($0) }
            board.excludedPlayerIDs = board.excludedPlayerIDs.filter { validPlayerIDs.contains($0) }

            let placedIDs = Set(board.placements.map { $0.playerID })
            let benchIDs = Set(board.benchPlayerIDs)
            let excludedIDs = Set(board.excludedPlayerIDs)

            for player in players {
                if placedIDs.contains(player.id) || benchIDs.contains(player.id) || excludedIDs.contains(player.id) {
                    continue
                }
                board.benchPlayerIDs.append(player.id)
            }

            board.opponentMarkers = normalizeOpponentMarkers(board.opponentMarkers)

            tacticsBoardStates[scenario.id] = board
        }
    }

    private func appendPlayerToAllBenchIfNeeded(_ playerID: UUID) {
        for scenario in tacticsScenarios {
            var board = tacticsBoardStates[scenario.id]
                ?? TacticsBoardState.empty(scenarioID: scenario.id, playerIDs: players.map { $0.id })
            let allIDs = Set(board.placements.map { $0.playerID })
                .union(board.benchPlayerIDs)
                .union(board.excludedPlayerIDs)
            if !allIDs.contains(playerID) {
                board.benchPlayerIDs.append(playerID)
            }
            tacticsBoardStates[scenario.id] = board
        }
        scheduleTacticsStateSync()
    }

    private func removePlayerFromAllBoardStates(_ playerID: UUID) {
        for scenario in tacticsScenarios {
            guard var board = tacticsBoardStates[scenario.id] else { continue }
            board.placements.removeAll { $0.playerID == playerID }
            board.benchPlayerIDs.removeAll { $0 == playerID }
            board.excludedPlayerIDs.removeAll { $0 == playerID }
            tacticsBoardStates[scenario.id] = board
        }
        scheduleTacticsStateSync()
    }

    private func removePlayerFromAnalysisReferences(_ playerID: UUID) {
        for index in analysisMarkers.indices where analysisMarkers[index].playerID == playerID {
            analysisMarkers[index].playerID = nil
        }
        for index in analysisClips.indices {
            analysisClips[index].playerIDs.removeAll { $0 == playerID }
        }
        for index in sharedClipReferences.indices {
            sharedClipReferences[index] = SharedClipReference(
                id: sharedClipReferences[index].id,
                clipID: sharedClipReferences[index].clipID,
                clipName: sharedClipReferences[index].clipName,
                playerIDs: sharedClipReferences[index].playerIDs.filter { $0 != playerID },
                threadID: sharedClipReferences[index].threadID,
                message: sharedClipReferences[index].message,
                backendMessageIDs: sharedClipReferences[index].backendMessageIDs,
                createdAt: sharedClipReferences[index].createdAt
            )
        }
    }

    private func normalizeOpponentMarkers(_ markers: [OpponentMarker]) -> [OpponentMarker] {
        var normalized = markers

        if normalized.count != 11 {
            normalized = OpponentMarker.defaultLine()
        }

        if looksLikeLegacyTopToBottomLayout(normalized) {
            normalized = OpponentMarker.defaultLine()
        }

        var seen: Set<UUID> = []
        for index in normalized.indices {
            let id = normalized[index].id
            if seen.contains(id) {
                normalized[index] = OpponentMarker(id: UUID(), point: normalized[index].point)
            }
            seen.insert(normalized[index].id)
        }

        return normalized
    }

    private func looksLikeLegacyTopToBottomLayout(_ markers: [OpponentMarker]) -> Bool {
        guard markers.count == 11 else { return false }
        let sortedMarkers = markers
            .map(\.point)
            .sorted { lhs, rhs in
                if lhs.x == rhs.x { return lhs.y < rhs.y }
                return lhs.x < rhs.x
            }
        let legacy = OpponentMarker.legacyTopToBottomLine()
            .sorted { lhs, rhs in
                if lhs.x == rhs.x { return lhs.y < rhs.y }
                return lhs.x < rhs.x
            }
        let tolerance = 0.001
        for index in 0..<legacy.count {
            if abs(sortedMarkers[index].x - legacy[index].x) > tolerance {
                return false
            }
            if abs(sortedMarkers[index].y - legacy[index].y) > tolerance {
                return false
            }
        }
        return true
    }

    private func clearSeededDataForBackendOnlyMode() {
        profile = CoachProfile(name: "", license: "", team: "", seasonGoal: "")
        personProfiles = []
        profileAuditEntries = []
        activePersonProfileID = nil

        players = []
        calendarCategories = [CalendarCategory.training, CalendarCategory.match]
        calendarEvents = []
        trainings = []
        trainingPlans = []
        trainingPhasesByPlan = [:]
        trainingExercisesByPhase = [:]
        trainingGroupsByPlan = [:]
        trainingBriefingsByGroup = [:]
        trainingReportsByPlan = [:]
        trainingTemplates = []
        trainingAvailabilityByPlan = [:]
        trainingDeviationsByPlan = [:]
        activeTrainingPlanID = nil

        matches = []
        threads = []
        feedbackEntries = []
        transactions = []
        files = []
        tactics = []
        tacticsScenarios = []
        tacticsBoardStates = [:]
        activeTacticsScenarioID = nil

        // Note: analysisVideoAssets intentionally NOT cleared — they hold
        // local file path mappings that must survive restarts.
        analysisSessions = []
        analysisMarkers = []
        analysisClips = []
        analysisDrawings = []
        activeAnalysisSessionID = nil
        sharedClipReferences = []

        messengerCurrentUser = nil
        messengerUserDirectory = []
        messengerChats = []
        messengerArchivedChats = []
        messengerMessagesByChat = [:]
        messengerSearchResults = []
        messengerOutboxItems = []
        messengerOutboxCount = 0
        messengerChatNextCursor = nil
        messengerMessageNextCursorByChat = [:]
        messengerRealtimeCursor = nil

        cloudFolders = []
        cloudFiles = []
        cloudUsage = .default
        cloudUploads = []
        cloudFileNextCursor = nil
        cloudLargestFiles = []
        cloudOldFiles = []
        selectedCloudFileID = nil
        cloudActiveFolderID = nil

        adminTasks = []
        adminPersons = []
        adminGroups = []
        adminInvitations = []
        adminAuditEntries = []
        adminSeasons = []
        activeAdminSeasonID = nil
    }
}

struct CoachProfile {
    let name: String
    let license: String
    let team: String
    let seasonGoal: String
}

struct TrainingSession: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
    let focus: String
}

struct MatchInfo: Identifiable {
    let id = UUID()
    let opponent: String
    let date: Date
    let homeAway: String
}

struct MessageThread: Identifiable {
    let id: UUID
    let title: String
    let lastMessage: String
    let unreadCount: Int

    init(id: UUID = UUID(), title: String, lastMessage: String, unreadCount: Int) {
        self.id = id
        self.title = title
        self.lastMessage = lastMessage
        self.unreadCount = unreadCount
    }
}

struct FeedbackEntry: Identifiable {
    let id = UUID()
    let player: String
    let summary: String
    let date: Date
}

struct TransactionEntry: Identifiable {
    let id = UUID()
    let title: String
    let amount: Double
    let date: Date
    let type: TransactionType
}

enum TransactionType {
    case income
    case expense
}

struct FileItem: Identifiable {
    let id = UUID()
    let name: String
    let category: String
}

struct TacticBoard: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

struct SharedClipReference: Identifiable {
    let id: UUID
    let clipID: UUID
    let clipName: String
    let playerIDs: [UUID]
    let threadID: UUID?
    let message: String
    let backendMessageIDs: [String]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        clipID: UUID,
        clipName: String,
        playerIDs: [UUID],
        threadID: UUID?,
        message: String,
        backendMessageIDs: [String],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.clipID = clipID
        self.clipName = clipName
        self.playerIDs = playerIDs
        self.threadID = threadID
        self.message = message
        self.backendMessageIDs = backendMessageIDs
        self.createdAt = createdAt
    }
}

struct AdminTask: Identifiable {
    let id = UUID()
    let title: String
    let due: String
}
