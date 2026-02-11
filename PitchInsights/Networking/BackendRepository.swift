import Foundation

struct BackendHealthResponse: Decodable {
    var status: String
}

struct BackendBootstrapResponse: Decodable {
    var status: String
    var service: String
    var version: String
    var time: String
}

final class BackendRepository {
    private let client: APIClient
    let auth: AuthService

    init(client: APIClient, auth: AuthService) {
        self.client = client
        self.auth = auth
    }

    func fetchProfile() async throws -> CoachProfileDTO {
        try await sendAuthorized(.get("/profile"))
    }

    func updateProfile(userId: String, request: UpdateProfileRequest) async throws -> PersonProfileDTO {
        let data = try encode(request)
        return try await sendAuthorized(.patch("/profiles/\(userId)", body: data))
    }

    func submitProfile(_ request: UpdateProfileRequest) async throws -> PersonProfileDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/profile", body: data))
    }

    func fetchPersonProfiles() async throws -> [PersonProfileDTO] {
        try await sendAuthorized(.get("/profiles"))
    }

    func upsertPersonProfile(_ request: UpsertPersonProfileRequest) async throws -> PersonProfileDTO {
        let data = try encode(request)
        if let id = request.id, !id.isEmpty {
            return try await sendAuthorized(.put("/profiles/\(id)", body: data))
        }
        return try await sendAuthorized(.post("/profiles", body: data))
    }

    func deletePersonProfile(profileID: String) async throws -> EmptyResponse {
        try await sendAuthorized(.delete("/profiles/\(profileID)"))
    }

    func fetchProfileAudit(profileID: String?) async throws -> [ProfileAuditEntryDTO] {
        if let profileID, !profileID.isEmpty {
            let items = [URLQueryItem(name: "profileId", value: profileID)]
            return try await sendAuthorized(.get("/profiles/audit", query: items))
        }
        return try await sendAuthorized(.get("/profiles/audit"))
    }

    func fetchAuthMe() async throws -> AuthMeDTO {
        try await sendAuthorized(.get("/auth/me"))
    }

    func logout(refreshToken: String) async throws -> EmptyResponse {
        let request = RefreshRequest(refreshToken: refreshToken)
        let data = try encode(request)
        return try await sendAuthorized(.post("/auth/logout", body: data))
    }

    func resolveOnboarding(_ request: OnboardingResolveRequest) async throws -> OnboardingResolveResponse {
        let data = try encode(request)
        return try await sendAuthorized(.post("/onboarding/resolve", body: data))
    }

    func searchClubs(query: String, region: String?) async throws -> [ClubSearchResultDTO] {
        var items = [URLQueryItem(name: "query", value: query)]
        if let region, !region.isEmpty {
            items.append(URLQueryItem(name: "region", value: region))
        }
        return try await sendAuthorized(.get("/clubs/search", query: items))
    }

    func createClub(_ request: ClubCreateRequest) async throws -> ClubDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/clubs", body: data))
    }

    func joinClub(_ request: ClubJoinRequest) async throws -> ClubJoinResponse {
        let data = try encode(request)
        return try await sendAuthorized(.post("/clubs/join", body: data))
    }

    func createTeam(_ request: TeamCreateRequest) async throws -> TeamDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/teams", body: data))
    }

    func completeOnboarding() async throws -> EmptyResponse {
        try await sendAuthorized(.post("/onboarding/complete"))
    }

    func fetchPlayers() async throws -> [PlayerDTO] {
        try await sendAuthorized(.get("/players"))
    }

    func fetchCalendarEvents() async throws -> [CalendarEventDTO] {
        try await sendAuthorized(.get("/calendar/events"))
    }

    func fetchCalendarCategories() async throws -> [CalendarCategoryDTO] {
        try await sendAuthorized(.get("/calendar/categories"))
    }

    func createCalendarEvent(_ request: CreateCalendarEventRequest) async throws -> CalendarEventDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/calendar/events", body: data))
    }

    func updateCalendarEvent(id: UUID, request: UpdateCalendarEventRequest) async throws -> CalendarEventDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/calendar/events/\(id.uuidString)", body: data))
    }

    func deleteCalendarEvent(id: UUID) async throws -> EmptyResponse {
        try await sendAuthorized(.delete("/calendar/events/\(id.uuidString)"))
    }

    func createPlayer(_ request: UpsertPlayerRequest) async throws -> PlayerDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/players", body: data))
    }

    func updatePlayer(id: UUID, request: UpsertPlayerRequest) async throws -> PlayerDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/players/\(id.uuidString)", body: data))
    }

    func deletePlayer(id: UUID) async throws -> EmptyResponse {
        try await sendAuthorized(.delete("/players/\(id.uuidString)"))
    }

    func fetchTacticsState() async throws -> TacticsStateDTO {
        try await sendAuthorized(.get("/tactics/state"))
    }

    func saveTacticsState(_ request: SaveTacticsStateRequest) async throws -> EmptyResponse {
        let data = try encode(request)
        return try await sendAuthorized(.put("/tactics/state", body: data))
    }

    func registerAnalysisVideo(_ request: AnalysisVideoRegisterRequest) async throws -> AnalysisVideoRegisterResponse {
        let data = try encode(request)
        return try await sendAuthorized(.post("/analysis/videos/register", body: data))
    }

    func uploadAnalysisVideo(uploadURL: URL, headers: [String: String], fileURL: URL) async throws {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = Endpoint.Method.put.rawValue
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (_, response) = try await URLSession.shared.upload(for: request, fromFile: fileURL)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(status: httpResponse.statusCode, data: Data())
        }
    }

    func completeAnalysisVideo(videoID: String, request: AnalysisVideoCompleteRequest) async throws -> AnalysisVideoCompleteResponse {
        let data = try encode(request)
        return try await sendAuthorized(.post("/analysis/videos/\(videoID)/complete", body: data))
    }

    func fetchPlaybackURL(videoID: String) async throws -> SignedPlaybackURLResponse {
        try await sendAuthorized(.get("/analysis/videos/\(videoID)/playback"))
    }

    func createAnalysisSession(_ request: CreateAnalysisSessionRequest) async throws -> AnalysisSessionDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/analysis/sessions", body: data))
    }

    func fetchAnalysisSessions() async throws -> [AnalysisSessionDTO] {
        try await sendAuthorized(.get("/analysis/sessions"))
    }

    func fetchAnalysisSession(id: String) async throws -> AnalysisSessionEnvelopeDTO {
        try await sendAuthorized(.get("/analysis/sessions/\(id)"))
    }

    func createAnalysisMarker(_ request: CreateAnalysisMarkerRequest) async throws -> AnalysisMarkerDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/analysis/markers", body: data))
    }

    func updateAnalysisMarker(id: String, request: UpdateAnalysisMarkerRequest) async throws -> AnalysisMarkerDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/analysis/markers/\(id)", body: data))
    }

    func deleteAnalysisMarker(id: String) async throws -> EmptyResponse {
        try await sendAuthorized(.delete("/analysis/markers/\(id)"))
    }

    func createAnalysisClip(_ request: CreateAnalysisClipRequest) async throws -> AnalysisClipDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/analysis/clips", body: data))
    }

    func updateAnalysisClip(id: String, request: UpdateAnalysisClipRequest) async throws -> AnalysisClipDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/analysis/clips/\(id)", body: data))
    }

    func deleteAnalysisClip(id: String) async throws -> EmptyResponse {
        try await sendAuthorized(.delete("/analysis/clips/\(id)"))
    }

    func saveAnalysisDrawings(sessionID: String, request: SaveAnalysisDrawingsRequest) async throws -> EmptyResponse {
        let data = try encode(request)
        return try await sendAuthorized(.put("/analysis/sessions/\(sessionID)/drawings", body: data))
    }

    func shareAnalysisClip(clipID: String, request: ShareAnalysisClipRequest) async throws -> ShareAnalysisClipResponse {
        let data = try encode(request)
        return try await sendAuthorized(.post("/analysis/clips/\(clipID)/share", body: data))
    }

    func fetchTrainingPlans(
        cursor: String?,
        limit: Int,
        from: Date?,
        to: Date?,
        coachID: String?
    ) async throws -> TrainingPlansPageDTO {
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let from {
            items.append(URLQueryItem(name: "from", value: ISO8601DateFormatter().string(from: from)))
        }
        if let to {
            items.append(URLQueryItem(name: "to", value: ISO8601DateFormatter().string(from: to)))
        }
        if let coachID, !coachID.isEmpty {
            items.append(URLQueryItem(name: "coachId", value: coachID))
        }
        return try await sendAuthorized(.get("/training/plans", query: items))
    }

    func fetchTrainingPlan(planID: String) async throws -> TrainingPlanEnvelopeDTO {
        try await sendAuthorized(.get("/training/plans/\(planID)"))
    }

    func createTrainingPlan(_ request: CreateTrainingPlanRequest) async throws -> TrainingPlanDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/training/plans", body: data))
    }

    func updateTrainingPlan(planID: String, request: UpdateTrainingPlanRequest) async throws -> TrainingPlanDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/training/plans/\(planID)", body: data))
    }

    func deleteTrainingPlan(planID: String) async throws -> EmptyResponse {
        try await sendAuthorized(.delete("/training/plans/\(planID)"))
    }

    func saveTrainingPhases(planID: String, request: SaveTrainingPhasesRequest) async throws -> [TrainingPhaseDTO] {
        let data = try encode(request)
        return try await sendAuthorized(.put("/training/plans/\(planID)/phases", body: data))
    }

    func saveTrainingExercises(planID: String, request: SaveTrainingExercisesRequest) async throws -> [TrainingExerciseDTO] {
        let data = try encode(request)
        return try await sendAuthorized(.put("/training/plans/\(planID)/exercises", body: data))
    }

    func createTrainingTemplate(_ request: CreateTrainingTemplateRequest) async throws -> TrainingExerciseTemplateDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/training/templates", body: data))
    }

    func fetchTrainingTemplates(query: String?, cursor: String?, limit: Int) async throws -> TrainingTemplatesPageDTO {
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let query, !query.isEmpty {
            items.append(URLQueryItem(name: "query", value: query))
        }
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await sendAuthorized(.get("/training/templates", query: items))
    }

    func createTrainingGroup(planID: String, request: UpsertTrainingGroupRequest) async throws -> TrainingGroupDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/training/plans/\(planID)/groups", body: data))
    }

    func updateTrainingGroup(groupID: String, request: UpsertTrainingGroupRequest) async throws -> TrainingGroupDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/training/groups/\(groupID)", body: data))
    }

    func saveTrainingGroupBriefing(groupID: String, request: SaveTrainingGroupBriefingRequest) async throws -> TrainingGroupBriefingDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/training/groups/\(groupID)/briefing", body: data))
    }

    func assignTrainingParticipants(planID: String, request: AssignTrainingParticipantsRequest) async throws -> [TrainingAvailabilitySnapshotDTO] {
        let data = try encode(request)
        return try await sendAuthorized(.put("/training/plans/\(planID)/participants", body: data))
    }

    func startTrainingLive(planID: String, request: StartTrainingLiveRequest) async throws -> TrainingPlanDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/training/plans/\(planID)/live/start", body: data))
    }

    func saveTrainingLiveState(planID: String, request: SaveTrainingLiveStateRequest) async throws -> TrainingPlanEnvelopeDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/training/plans/\(planID)/live/state", body: data))
    }

    func createTrainingLiveDeviation(planID: String, request: CreateTrainingLiveDeviationRequest) async throws -> TrainingLiveDeviationDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/training/plans/\(planID)/live/deviations", body: data))
    }

    func createTrainingReport(planID: String, request: CreateTrainingReportRequest) async throws -> TrainingReportDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/training/plans/\(planID)/report", body: data))
    }

    func fetchTrainingReport(planID: String) async throws -> TrainingReportDTO {
        try await sendAuthorized(.get("/training/plans/\(planID)/report"))
    }

    func linkTrainingToCalendar(planID: String, request: LinkTrainingCalendarRequest) async throws -> CalendarEventDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/training/plans/\(planID)/calendar-link", body: data))
    }

    func duplicateTrainingPlan(planID: String, request: DuplicateTrainingPlanRequest) async throws -> TrainingPlanDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/training/plans/\(planID)/duplicate", body: data))
    }

    func fetchTrainings() async throws -> [TrainingSessionDTO] {
        try await sendAuthorized(.get("/trainings"))
    }

    func fetchMatches() async throws -> [MatchInfoDTO] {
        try await sendAuthorized(.get("/matches"))
    }

    func fetchThreads() async throws -> [MessageThreadDTO] {
        try await sendAuthorized(.get("/messages/threads"))
    }

    func fetchMessengerChats(
        cursor: String?,
        limit: Int,
        includeArchived: Bool,
        query: String?
    ) async throws -> MessengerChatsPageDTO {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "archived", value: includeArchived ? "true" : "false")
        ]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let query, !query.isEmpty {
            items.append(URLQueryItem(name: "q", value: query))
        }
        return try await sendAuthorized(.get("/messages/chats", query: items))
    }

    func createDirectChat(_ request: CreateDirectChatRequest) async throws -> MessengerChatDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/messages/chats/direct", body: data))
    }

    func createGroupChat(_ request: CreateGroupChatRequest) async throws -> MessengerChatDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/messages/chats/group", body: data))
    }

    func updateChat(chatID: String, request: UpdateChatRequest) async throws -> MessengerChatDTO {
        let data = try encode(request)
        return try await sendAuthorized(.patch("/messages/chats/\(chatID)", body: data))
    }

    func archiveChat(chatID: String) async throws -> MessengerChatDTO {
        try await sendAuthorized(.post("/messages/chats/\(chatID)/archive"))
    }

    func unarchiveChat(chatID: String) async throws -> MessengerChatDTO {
        try await sendAuthorized(.post("/messages/chats/\(chatID)/unarchive"))
    }

    func fetchMessages(chatID: String, cursor: String?, limit: Int) async throws -> MessengerMessagesPageDTO {
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await sendAuthorized(.get("/messages/chats/\(chatID)/messages", query: items))
    }

    func sendMessage(chatID: String, request: CreateMessageRequest) async throws -> MessengerMessageDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/messages/chats/\(chatID)/messages", body: data))
    }

    func deleteMessage(chatID: String, messageID: String) async throws -> EmptyResponse {
        try await sendAuthorized(.delete("/messages/chats/\(chatID)/messages/\(messageID)"))
    }

    func markChatRead(chatID: String, request: MarkChatReadRequest) async throws -> EmptyResponse {
        let data = try encode(request)
        return try await sendAuthorized(.post("/messages/chats/\(chatID)/read", body: data))
    }

    func fetchReadReceipts(chatID: String, messageID: String) async throws -> [MessengerReadReceiptDTO] {
        let items = [URLQueryItem(name: "messageId", value: messageID)]
        return try await sendAuthorized(.get("/messages/chats/\(chatID)/read-receipts", query: items))
    }

    func searchMessenger(
        query: String,
        cursor: String?,
        limit: Int,
        includeArchived: Bool
    ) async throws -> MessengerSearchPageDTO {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "includeArchived", value: includeArchived ? "true" : "false")
        ]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await sendAuthorized(.get("/messages/search", query: items))
    }

    func registerMessengerMedia(_ request: MessengerMediaRegisterRequest) async throws -> MessengerMediaRegisterResponse {
        let data = try encode(request)
        return try await sendAuthorized(.post("/messages/media/register", body: data))
    }

    func completeMessengerMedia(mediaID: String, request: MessengerMediaCompleteRequest) async throws -> MessengerMediaCompleteResponse {
        let data = try encode(request)
        return try await sendAuthorized(.post("/messages/media/\(mediaID)/complete", body: data))
    }

    func fetchMessengerMediaDownloadURL(mediaID: String) async throws -> MessengerMediaDownloadResponse {
        try await sendAuthorized(.get("/messages/media/\(mediaID)/download"))
    }

    func fetchMessengerRealtimeToken() async throws -> MessengerRealtimeTokenResponse {
        try await sendAuthorized(.get("/messages/realtime/token"))
    }

    func fetchFeedback() async throws -> [FeedbackEntryDTO] {
        try await sendAuthorized(.get("/feedback"))
    }

    func fetchTransactions() async throws -> [TransactionEntryDTO] {
        try await sendAuthorized(.get("/finance/transactions"))
    }

    func fetchCashBootstrap() async throws -> CashBootstrapDTO {
        try await sendAuthorized(.get("/finance/cash/bootstrap"))
    }

    func fetchCashTransactions(
        cursor: String?,
        limit: Int,
        from: Date?,
        to: Date?,
        categoryID: UUID?,
        playerID: UUID?,
        status: CashPaymentStatus?,
        type: CashTransactionKind?,
        query: String?
    ) async throws -> CashTransactionsPageDTO {
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        let iso = ISO8601DateFormatter()
        if let from {
            items.append(URLQueryItem(name: "from", value: iso.string(from: from)))
        }
        if let to {
            items.append(URLQueryItem(name: "to", value: iso.string(from: to)))
        }
        if let categoryID {
            items.append(URLQueryItem(name: "categoryId", value: categoryID.uuidString))
        }
        if let playerID {
            items.append(URLQueryItem(name: "playerId", value: playerID.uuidString))
        }
        if let status {
            items.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        if let type {
            items.append(URLQueryItem(name: "type", value: type.rawValue))
        }
        if let query, !query.isEmpty {
            items.append(URLQueryItem(name: "q", value: query))
        }
        return try await sendAuthorized(.get("/finance/cash/transactions", query: items))
    }

    func createCashTransaction(_ request: UpsertCashTransactionRequest) async throws -> CashTransactionDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/finance/cash/transactions", body: data))
    }

    func updateCashTransaction(transactionID: String, request: UpsertCashTransactionRequest) async throws -> CashTransactionDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/finance/cash/transactions/\(transactionID)", body: data))
    }

    func deleteCashTransaction(transactionID: String) async throws -> EmptyResponse {
        try await sendAuthorized(.delete("/finance/cash/transactions/\(transactionID)"))
    }

    func createCashContribution(request: UpsertMonthlyContributionRequest) async throws -> MonthlyContributionDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/finance/cash/contributions", body: data))
    }

    func upsertCashContribution(contributionID: String, request: UpsertMonthlyContributionRequest) async throws -> MonthlyContributionDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/finance/cash/contributions/\(contributionID)", body: data))
    }

    func sendCashPaymentReminder(request: SendCashReminderRequest) async throws -> EmptyResponse {
        let data = try encode(request)
        return try await sendAuthorized(.post("/finance/cash/contributions/reminders", body: data))
    }

    func createCashGoal(request: UpsertCashGoalRequest) async throws -> CashGoalDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/finance/cash/goals", body: data))
    }

    func updateCashGoal(goalID: String, request: UpsertCashGoalRequest) async throws -> CashGoalDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/finance/cash/goals/\(goalID)", body: data))
    }

    func deleteCashGoal(goalID: String) async throws -> EmptyResponse {
        try await sendAuthorized(.delete("/finance/cash/goals/\(goalID)"))
    }

    func fetchFiles() async throws -> [FileItemDTO] {
        try await sendAuthorized(.get("/files"))
    }

    func fetchCloudFilesBootstrap(teamID: String) async throws -> CloudFilesBootstrapDTO {
        let query = [URLQueryItem(name: "teamId", value: teamID)]
        return try await sendAuthorized(.get("/cloud/files/bootstrap", query: query))
    }

    func fetchCloudFiles(_ request: CloudFilesQueryRequest) async throws -> CloudFilesPageDTO {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "teamId", value: request.teamID),
            URLQueryItem(name: "status", value: request.status),
            URLQueryItem(name: "limit", value: "\(request.limit)"),
            URLQueryItem(name: "sortField", value: request.sortField),
            URLQueryItem(name: "sortDirection", value: request.sortDirection)
        ]
        if let cursor = request.cursor, !cursor.isEmpty {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let q = request.query, !q.isEmpty {
            query.append(URLQueryItem(name: "q", value: q))
        }
        if let type = request.type, !type.isEmpty {
            query.append(URLQueryItem(name: "type", value: type))
        }
        if let folderID = request.folderID, !folderID.isEmpty {
            query.append(URLQueryItem(name: "folderId", value: folderID))
        }
        if let owner = request.ownerUserID, !owner.isEmpty {
            query.append(URLQueryItem(name: "ownerUserId", value: owner))
        }
        let iso = ISO8601DateFormatter()
        if let from = request.from {
            query.append(URLQueryItem(name: "from", value: iso.string(from: from)))
        }
        if let to = request.to {
            query.append(URLQueryItem(name: "to", value: iso.string(from: to)))
        }
        if let min = request.minSizeBytes {
            query.append(URLQueryItem(name: "minSizeBytes", value: "\(min)"))
        }
        if let max = request.maxSizeBytes {
            query.append(URLQueryItem(name: "maxSizeBytes", value: "\(max)"))
        }
        return try await sendAuthorized(.get("/cloud/files", query: query))
    }

    func fetchCloudTrash(_ request: CloudFilesQueryRequest) async throws -> CloudFilesPageDTO {
        var updated = request
        updated = CloudFilesQueryRequest(
            teamID: request.teamID,
            status: "trash",
            cursor: request.cursor,
            limit: request.limit,
            query: request.query,
            type: request.type,
            folderID: request.folderID,
            ownerUserID: request.ownerUserID,
            from: request.from,
            to: request.to,
            minSizeBytes: request.minSizeBytes,
            maxSizeBytes: request.maxSizeBytes,
            sortField: request.sortField,
            sortDirection: request.sortDirection
        )
        return try await fetchCloudFiles(updated)
    }

    func createCloudFolder(_ request: CreateCloudFolderRequest) async throws -> CloudFolderDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/cloud/folders", body: data))
    }

    func updateCloudFolder(folderID: String, request: UpdateCloudFolderRequest) async throws -> CloudFolderDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/cloud/folders/\(folderID)", body: data))
    }

    func registerCloudFileUpload(_ request: RegisterCloudFileUploadRequest) async throws -> RegisterCloudFileUploadResponse {
        let data = try encode(request)
        return try await sendAuthorized(.post("/cloud/files/register", body: data))
    }

    func uploadCloudFileChunk(
        uploadURL: URL,
        uploadID: String,
        partNumber: Int,
        totalParts: Int,
        headers: [String: String],
        contentRange: String,
        data: Data
    ) async throws -> String {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = Endpoint.Method.put.rawValue
        request.setValue(uploadID, forHTTPHeaderField: "X-Upload-ID")
        request.setValue("\(partNumber)", forHTTPHeaderField: "X-Part-Number")
        request.setValue("\(totalParts)", forHTTPHeaderField: "X-Total-Parts")
        request.setValue(contentRange, forHTTPHeaderField: "Content-Range")
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(status: httpResponse.statusCode, data: Data())
        }
        return httpResponse.value(forHTTPHeaderField: "ETag") ?? "part-\(partNumber)"
    }

    func completeCloudFileUpload(fileID: String, request: CompleteCloudFileUploadRequest) async throws -> CloudFileDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/cloud/files/\(fileID)/complete", body: data))
    }

    func updateCloudFile(fileID: String, request: UpdateCloudFileRequest) async throws -> CloudFileDTO {
        let data = try encode(request)
        return try await sendAuthorized(.patch("/cloud/files/\(fileID)", body: data))
    }

    func moveCloudFile(fileID: String, request: MoveCloudFileRequest) async throws -> CloudFileDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/cloud/files/\(fileID)/move", body: data))
    }

    func trashCloudFile(fileID: String, request: TrashCloudFileRequest) async throws -> CloudFileDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/cloud/files/\(fileID)/trash", body: data))
    }

    func restoreCloudFile(fileID: String, request: RestoreCloudFileRequest) async throws -> CloudFileDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/cloud/files/\(fileID)/restore", body: data))
    }

    func deleteCloudFilePermanently(fileID: String) async throws -> EmptyResponse {
        try await sendAuthorized(.delete("/cloud/files/\(fileID)"))
    }

    func fetchLargestCloudFiles(teamID: String, limit: Int) async throws -> [CloudFileDTO] {
        let query = [
            URLQueryItem(name: "teamId", value: teamID),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        return try await sendAuthorized(.get("/cloud/files/largest", query: query))
    }

    func fetchOldCloudFiles(teamID: String, olderThanDays: Int, limit: Int) async throws -> [CloudFileDTO] {
        let query = [
            URLQueryItem(name: "teamId", value: teamID),
            URLQueryItem(name: "olderThanDays", value: "\(olderThanDays)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        return try await sendAuthorized(.get("/cloud/files/old", query: query))
    }

    func fetchTactics() async throws -> [TacticBoardDTO] {
        try await sendAuthorized(.get("/tactics"))
    }

    func fetchAnalysisClips() async throws -> [LegacyAnalysisClipDTO] {
        try await sendAuthorized(.get("/analysis/clips"))
    }

    func fetchAdminTasks() async throws -> [AdminTaskDTO] {
        try await sendAuthorized(.get("/admin/tasks"))
    }

    func fetchAdminBootstrap() async throws -> AdminBootstrapDTO {
        try await sendAuthorized(.get("/admin/bootstrap"))
    }

    func createAdminPerson(_ request: UpsertAdminPersonRequest) async throws -> AdminPersonDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/admin/persons", body: data))
    }

    func updateAdminPerson(personID: String, request: UpsertAdminPersonRequest) async throws -> AdminPersonDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/admin/persons/\(personID)", body: data))
    }

    func deleteAdminPerson(personID: String) async throws -> EmptyResponse {
        try await sendAuthorized(.delete("/admin/persons/\(personID)"))
    }

    func createAdminGroup(_ request: UpsertAdminGroupRequest) async throws -> AdminGroupDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/admin/groups", body: data))
    }

    func updateAdminGroup(groupID: String, request: UpsertAdminGroupRequest) async throws -> AdminGroupDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/admin/groups/\(groupID)", body: data))
    }

    func deleteAdminGroup(groupID: String) async throws -> EmptyResponse {
        try await sendAuthorized(.delete("/admin/groups/\(groupID)"))
    }

    func createAdminInvitation(_ request: CreateAdminInvitationRequest) async throws -> AdminInvitationDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/admin/invitations", body: data))
    }

    func updateAdminInvitationStatus(invitationID: String, request: UpdateAdminInvitationStatusRequest) async throws -> AdminInvitationDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/admin/invitations/\(invitationID)/status", body: data))
    }

    func resendAdminInvitation(invitationID: String) async throws -> AdminInvitationDTO {
        try await sendAuthorized(.post("/admin/invitations/\(invitationID)/resend"))
    }

    func fetchAdminAuditLogs(
        cursor: String?,
        limit: Int,
        personName: String?,
        area: String?,
        from: Date?,
        to: Date?
    ) async throws -> AdminAuditEntriesPageDTO {
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let personName, !personName.isEmpty {
            items.append(URLQueryItem(name: "person", value: personName))
        }
        if let area, !area.isEmpty {
            items.append(URLQueryItem(name: "area", value: area))
        }
        let iso = ISO8601DateFormatter()
        if let from {
            items.append(URLQueryItem(name: "from", value: iso.string(from: from)))
        }
        if let to {
            items.append(URLQueryItem(name: "to", value: iso.string(from: to)))
        }
        return try await sendAuthorized(.get("/admin/audit", query: items))
    }

    func createAdminSeason(_ request: UpsertAdminSeasonRequest) async throws -> AdminSeasonDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/admin/seasons", body: data))
    }

    func updateAdminSeason(seasonID: String, request: UpsertAdminSeasonRequest) async throws -> AdminSeasonDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/admin/seasons/\(seasonID)", body: data))
    }

    func updateAdminSeasonStatus(seasonID: String, request: UpdateAdminSeasonStatusRequest) async throws -> AdminSeasonDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/admin/seasons/\(seasonID)/status", body: data))
    }

    func setAdminActiveSeason(_ request: SetActiveSeasonRequest) async throws -> EmptyResponse {
        let data = try encode(request)
        return try await sendAuthorized(.post("/admin/seasons/activate", body: data))
    }

    func duplicateAdminSeasonRoster(targetSeasonID: String, request: DuplicateSeasonRosterRequest) async throws -> EmptyResponse {
        let data = try encode(request)
        return try await sendAuthorized(.post("/admin/seasons/\(targetSeasonID)/duplicate-roster", body: data))
    }

    func saveAdminClubSettings(_ request: UpsertAdminClubSettingsRequest) async throws -> AdminClubSettingsDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/admin/settings/club", body: data))
    }

    func saveAdminMessengerRules(_ request: UpsertAdminMessengerRulesRequest) async throws -> AdminMessengerRulesDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/admin/settings/messenger", body: data))
    }

    func fetchSettingsBootstrap() async throws -> SettingsBootstrapDTO {
        try await sendAuthorized(.get("/settings/bootstrap"))
    }

    func savePresentationSettings(_ request: SavePresentationSettingsRequest) async throws -> PresentationSettingsDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/settings/presentation", body: data))
    }

    func saveNotificationSettings(_ request: SaveNotificationSettingsRequest) async throws -> NotificationSettingsDTO {
        let data = try encode(request)
        return try await sendAuthorized(.put("/settings/notifications", body: data))
    }

    func fetchSecuritySettings() async throws -> SecuritySettingsDTO {
        try await sendAuthorized(.get("/settings/security"))
    }

    func changePassword(_ request: ChangePasswordRequest) async throws -> EmptyResponse {
        let data = try encode(request)
        return try await sendAuthorized(.post("/settings/security/password", body: data))
    }

    func updateTwoFactor(_ request: UpdateTwoFactorRequest) async throws -> SecuritySettingsDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/settings/security/two-factor", body: data))
    }

    func revokeSession(_ request: RevokeSessionRequest) async throws -> SecuritySettingsDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/settings/security/sessions/revoke", body: data))
    }

    func revokeAllSessions() async throws -> SecuritySettingsDTO {
        try await sendAuthorized(.post("/settings/security/sessions/revoke-all"))
    }

    func fetchAppInfoSettings() async throws -> AppInfoSettingsDTO {
        try await sendAuthorized(.get("/settings/app-info"))
    }

    func submitSettingsFeedback(_ request: SubmitSettingsFeedbackRequest) async throws -> EmptyResponse {
        let data = try encode(request)
        return try await sendAuthorized(.post("/settings/feedback", body: data))
    }

    func switchAccountContext(_ request: SwitchAccountContextRequest) async throws -> AccountSettingsDTO {
        let data = try encode(request)
        return try await sendAuthorized(.post("/settings/account/context", body: data))
    }

    func deactivateAccount() async throws -> EmptyResponse {
        try await sendAuthorized(.post("/settings/account/deactivate"))
    }

    func leaveCurrentTeam() async throws -> EmptyResponse {
        try await sendAuthorized(.post("/settings/account/leave-team"))
    }

    func healthCheck() async throws -> BackendHealthResponse {
        try await client.send(.get("/health"))
    }

    func bootstrapCheck() async throws -> BackendBootstrapResponse {
        try await client.send(.get("/bootstrap"))
    }

    func logoutCurrentSession() async {
        await auth.logout(using: self)
    }

    private func sendAuthorized<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        do {
            return try await client.send(endpoint, token: auth.accessToken)
        } catch NetworkError.httpError(let status, let data) where status == 401 {
            guard auth.refreshToken != nil else {
                throw NetworkError.httpError(status: status, data: data)
            }
            try await auth.refresh()
            return try await client.send(endpoint, token: auth.accessToken)
        }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }
}
