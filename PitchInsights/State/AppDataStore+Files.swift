import Foundation

enum CloudFilesStoreError: LocalizedError {
    case storageLimitReached
    case folderNotFound
    case fileNotFound
    case backendIdentifierMissing
    case noLocalVideoCache

    var errorDescription: String? {
        switch self {
        case .storageLimitReached:
            return "Speicher voll. Bitte zuerst Dateien löschen."
        case .folderNotFound:
            return "Ordner nicht gefunden."
        case .fileNotFound:
            return "Datei nicht gefunden."
        case .backendIdentifierMissing:
            return "Server-ID fehlt."
        case .noLocalVideoCache:
            return "Diese Datei muss zuerst serverseitig einer Analyse zugeordnet werden."
        }
    }
}

@MainActor
extension AppDataStore {
    func bootstrapCloudFiles() async {
        cloudConnectionState = .syncing
        do {
            let bootstrap = try await cloudFileSyncService.fetchBootstrap(teamID: activeCloudTeamID())
            applyCloudBootstrap(bootstrap)
            cloudConnectionState = .live
            syncLegacyFilesList()
            await refreshCloudCleanupSuggestions()
        } catch {
            if isConnectivityFailure(error) {
                cloudConnectionState = .failed(error.localizedDescription)
                cloudLastErrorMessage = error.localizedDescription
            } else {
                print("[client] bootstrapCloudFiles: endpoint not available — \(error.localizedDescription)")
                cloudConnectionState = .live
            }
        }
    }

    func refreshCloudFiles(
        filter: CloudFileFilterState,
        cursor: String? = nil
    ) async {
        do {
            let page = try await cloudFileSyncService.fetchFiles(makeCloudQueryRequest(filter: filter, cursor: cursor))
            let mapped = page.items.map(mapCloudFile(dto:))
            mergeCloudFiles(mapped, reset: cursor == nil)
            cloudFileNextCursor = page.nextCursor
            cloudConnectionState = .live
            syncLegacyFilesList()
        } catch {
            if isConnectivityFailure(error) {
                cloudConnectionState = .failed(error.localizedDescription)
                cloudLastErrorMessage = error.localizedDescription
            } else {
                print("[client] refreshCloudFiles: endpoint not available — \(error.localizedDescription)")
            }
        }
    }

    func refreshCloudTrash(
        filter: CloudFileFilterState,
        cursor: String? = nil
    ) async {
        var trashFilter = filter
        trashFilter.status = .trash
        do {
            let page = try await cloudFileSyncService.fetchTrash(makeCloudQueryRequest(filter: trashFilter, cursor: cursor))
            let mapped = page.items.map(mapCloudFile(dto:))
            mergeCloudFiles(mapped, reset: cursor == nil)
            cloudFileNextCursor = page.nextCursor
        } catch {
            if isConnectivityFailure(error) {
                cloudConnectionState = .failed(error.localizedDescription)
                cloudLastErrorMessage = error.localizedDescription
            } else {
                print("[client] refreshCloudTrash: endpoint not available — \(error.localizedDescription)")
            }
        }
    }

    func createCloudFolder(name: String, parentID: UUID?) async throws -> CloudFolder {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CloudFilesStoreError.folderNotFound
        }

        let dto = try await cloudFileSyncService.createFolder(
            CreateCloudFolderRequest(
                teamID: activeCloudTeamID(),
                parentFolderID: cloudFolders.first(where: { $0.id == parentID })?.backendID,
                name: trimmed
            )
        )
        let mapped = mapCloudFolder(dto: dto)
        upsertCloudFolder(mapped)
        cloudActiveFolderID = mapped.id
        return mapped
    }

    func renameCloudFolder(folderID: UUID, name: String) async throws {
        guard let index = cloudFolders.firstIndex(where: { $0.id == folderID }) else {
            throw CloudFilesStoreError.folderNotFound
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        cloudFolders[index].name = trimmed
        cloudFolders[index].updatedAt = Date()

        guard let backendID = cloudFolders[index].backendID else {
            throw CloudFilesStoreError.backendIdentifierMissing
        }
        let dto = try await cloudFileSyncService.updateFolder(
            folderID: backendID,
            request: UpdateCloudFolderRequest(name: trimmed, parentFolderID: nil)
        )
        upsertCloudFolder(mapCloudFolder(dto: dto))
    }

    func moveCloudFolder(folderID: UUID, parentID: UUID?) async throws {
        guard let index = cloudFolders.firstIndex(where: { $0.id == folderID }) else {
            throw CloudFilesStoreError.folderNotFound
        }
        cloudFolders[index].parentID = parentID
        cloudFolders[index].parentBackendID = cloudFolders.first(where: { $0.id == parentID })?.backendID
        cloudFolders[index].updatedAt = Date()

        guard let backendID = cloudFolders[index].backendID else {
            throw CloudFilesStoreError.backendIdentifierMissing
        }
        let dto = try await cloudFileSyncService.updateFolder(
            folderID: backendID,
            request: UpdateCloudFolderRequest(
                name: nil,
                parentFolderID: cloudFolders.first(where: { $0.id == parentID })?.backendID
            )
        )
        upsertCloudFolder(mapCloudFolder(dto: dto))
    }

    func uploadCloudFile(
        from sourceURL: URL,
        preferredType: CloudFileType? = nil,
        moduleHint: CloudModuleHint = .generic,
        folderID: UUID? = nil,
        tags: [String] = [],
        visibility: CloudFileVisibility = .teamWide,
        linkedAnalysisSessionID: UUID? = nil,
        linkedAnalysisClipID: UUID? = nil,
        linkedTacticsScenarioID: UUID? = nil,
        linkedTrainingPlanID: UUID? = nil
    ) async throws -> CloudFile {
        let imported = try cloudFileStore.persistImportedFile(from: sourceURL)
        defer {
            cloudFileStore.removeFile(relativePath: imported.localRelativePath)
        }
        let resolvedType = preferredType ?? imported.inferredType
        if cloudUsage.remainingBytes < imported.fileSize {
            throw CloudFilesStoreError.storageLimitReached
        }

        let progressID = UUID()
        cloudUploads.insert(
            CloudUploadProgress(
                id: progressID,
                filename: imported.originalFilename,
                totalBytes: imported.fileSize,
                uploadedBytes: 0,
                state: .queued,
                message: nil
            ),
            at: 0
        )

        do {
            let mapped: CloudFile
            updateUploadProgress(progressID: progressID, uploadedBytes: 0, state: .uploading, message: nil)
            let dto = try await cloudFileSyncService.registerAndUploadFile(
                importedFile: imported,
                request: RegisterCloudFileUploadRequest(
                    teamID: activeCloudTeamID(),
                    folderID: cloudFolders.first(where: { $0.id == (folderID ?? resolveDefaultFolderID(for: resolvedType)) })?.backendID,
                    name: imported.originalFilename,
                    originalName: imported.originalFilename,
                    type: resolvedType.rawValue,
                    mimeType: imported.mimeType,
                    sizeBytes: imported.fileSize,
                    moduleHint: moduleHint.rawValue,
                    visibility: visibility.rawValue,
                    tags: sanitizeTags(tags),
                    checksum: imported.sha256,
                    linkedAnalysisSessionID: linkedAnalysisSessionID?.uuidString,
                    linkedAnalysisClipID: linkedAnalysisClipID?.uuidString,
                    linkedTacticsScenarioID: linkedTacticsScenarioID?.uuidString,
                    linkedTrainingPlanID: linkedTrainingPlanID?.uuidString
                ),
                onProgress: { [progressID] uploaded, total in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.updateUploadProgress(progressID: progressID, uploadedBytes: uploaded, state: .uploading, message: nil)
                        if let index = self.cloudUploads.firstIndex(where: { $0.id == progressID }) {
                            self.cloudUploads[index].totalBytes = total
                        }
                    }
                }
            )
            var remote = mapCloudFile(dto: dto)
            remote.localCacheRelativePath = nil
            mapped = remote

            upsertCloudFile(mapped)
            cloudUsage.usedBytes += mapped.sizeBytes
            cloudUsage.updatedAt = Date()
            updateUploadProgress(progressID: progressID, uploadedBytes: imported.fileSize, state: .ready, message: nil)
            syncLegacyFilesList()
            return mapped
        } catch {
            updateUploadProgress(progressID: progressID, uploadedBytes: 0, state: .failed, message: error.localizedDescription)
            throw error
        }
    }

    func updateCloudFile(
        fileID: UUID,
        name: String? = nil,
        tags: [String]? = nil,
        visibility: CloudFileVisibility? = nil
    ) async throws {
        guard let index = cloudFiles.firstIndex(where: { $0.id == fileID }) else {
            throw CloudFilesStoreError.fileNotFound
        }

        if let name {
            cloudFiles[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let tags {
            cloudFiles[index].tags = sanitizeTags(tags)
        }
        if let visibility {
            cloudFiles[index].visibility = visibility
        }
        cloudFiles[index].updatedAt = Date()
        syncLegacyFilesList()

        guard let backendID = cloudFiles[index].backendID else {
            throw CloudFilesStoreError.backendIdentifierMissing
        }

        let dto = try await cloudFileSyncService.updateFile(
            fileID: backendID,
            request: UpdateCloudFileRequest(
                name: name,
                tags: tags.map(sanitizeTags(_:)),
                visibility: visibility?.rawValue,
                sharedUserIDs: nil,
                moduleHint: nil,
                linkedAnalysisSessionID: cloudFiles[index].linkedAnalysisSessionID?.uuidString,
                linkedAnalysisClipID: cloudFiles[index].linkedAnalysisClipID?.uuidString,
                linkedTacticsScenarioID: cloudFiles[index].linkedTacticsScenarioID?.uuidString,
                linkedTrainingPlanID: cloudFiles[index].linkedTrainingPlanID?.uuidString
            )
        )
        upsertCloudFile(mapCloudFile(dto: dto))
        syncLegacyFilesList()
    }

    func moveCloudFile(fileID: UUID, targetFolderID: UUID?) async throws {
        guard let index = cloudFiles.firstIndex(where: { $0.id == fileID }) else {
            throw CloudFilesStoreError.fileNotFound
        }
        cloudFiles[index].folderID = targetFolderID
        cloudFiles[index].folderBackendID = cloudFolders.first(where: { $0.id == targetFolderID })?.backendID
        cloudFiles[index].updatedAt = Date()
        syncLegacyFilesList()

        guard let backendID = cloudFiles[index].backendID else {
            throw CloudFilesStoreError.backendIdentifierMissing
        }
        let dto = try await cloudFileSyncService.moveFile(
            fileID: backendID,
            request: MoveCloudFileRequest(folderID: cloudFolders.first(where: { $0.id == targetFolderID })?.backendID)
        )
        upsertCloudFile(mapCloudFile(dto: dto))
    }

    func moveCloudFileToTrash(fileID: UUID) async throws {
        guard let index = cloudFiles.firstIndex(where: { $0.id == fileID }) else {
            throw CloudFilesStoreError.fileNotFound
        }
        cloudFiles[index].deletedAt = Date()
        cloudFiles[index].updatedAt = Date()
        syncLegacyFilesList()

        guard let backendID = cloudFiles[index].backendID else {
            throw CloudFilesStoreError.backendIdentifierMissing
        }
        let dto = try await cloudFileSyncService.trashFile(
            fileID: backendID,
            request: TrashCloudFileRequest(deletedAt: Date())
        )
        upsertCloudFile(mapCloudFile(dto: dto))
    }

    func restoreCloudFile(fileID: UUID, targetFolderID: UUID?) async throws {
        guard let index = cloudFiles.firstIndex(where: { $0.id == fileID }) else {
            throw CloudFilesStoreError.fileNotFound
        }
        cloudFiles[index].deletedAt = nil
        cloudFiles[index].folderID = targetFolderID
        cloudFiles[index].folderBackendID = cloudFolders.first(where: { $0.id == targetFolderID })?.backendID
        cloudFiles[index].updatedAt = Date()
        syncLegacyFilesList()

        guard let backendID = cloudFiles[index].backendID else {
            throw CloudFilesStoreError.backendIdentifierMissing
        }
        let dto = try await cloudFileSyncService.restoreFile(
            fileID: backendID,
            request: RestoreCloudFileRequest(folderID: cloudFolders.first(where: { $0.id == targetFolderID })?.backendID)
        )
        upsertCloudFile(mapCloudFile(dto: dto))
    }

    func deleteCloudFilePermanently(fileID: UUID) async throws {
        guard let index = cloudFiles.firstIndex(where: { $0.id == fileID }) else {
            throw CloudFilesStoreError.fileNotFound
        }
        let target = cloudFiles[index]
        cloudFiles.remove(at: index)
        cloudUsage.usedBytes = max(0, cloudUsage.usedBytes - target.sizeBytes)
        cloudUsage.updatedAt = Date()
        syncLegacyFilesList()

        guard let backendID = target.backendID else {
            throw CloudFilesStoreError.backendIdentifierMissing
        }
        try await cloudFileSyncService.deleteFilePermanently(fileID: backendID)
    }

    func openCloudFile(fileID: UUID, appState: AppState) async {
        guard let file = cloudFiles.first(where: { $0.id == fileID }) else { return }
        await fileOpenRouter.open(file: file, appState: appState, dataStore: self)
    }

    func cloudFilesForUI(
        filter: CloudFileFilterState
    ) -> [CloudFile] {
        let query = filter.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let result = cloudFiles.filter { file in
            if filter.status == .active, file.deletedAt != nil { return false }
            if filter.status == .trash, file.deletedAt == nil { return false }
            if let type = filter.type, file.type != type { return false }
            if let folderID = filter.folderID, file.folderID != folderID { return false }
            if let owner = filter.ownerUserID, !owner.isEmpty, file.ownerUserID != owner { return false }
            if let from = filter.fromDate, file.updatedAt < from { return false }
            if let to = filter.toDate, file.updatedAt > to { return false }
            if let min = filter.minSizeBytes, file.sizeBytes < min { return false }
            if let max = filter.maxSizeBytes, file.sizeBytes > max { return false }
            if !query.isEmpty {
                let tags = file.tags.joined(separator: " ").lowercased()
                if !file.name.lowercased().contains(query)
                    && !file.originalName.lowercased().contains(query)
                    && !tags.contains(query) {
                    return false
                }
            }
            return true
        }

        return sortCloudFiles(result, field: filter.sortField, direction: filter.sortDirection)
    }

    func refreshCloudCleanupSuggestions() async {
        do {
            let largestDTO = try await cloudFileSyncService.listLargestFiles(teamID: activeCloudTeamID(), limit: 8)
            cloudLargestFiles = largestDTO.map(mapCloudFile(dto:))
            let oldDTO = try await cloudFileSyncService.listOldFiles(teamID: activeCloudTeamID(), olderThanDays: 90, limit: 8)
            cloudOldFiles = oldDTO.map(mapCloudFile(dto:))
        } catch {
            cloudLastErrorMessage = error.localizedDescription
        }
    }

    func createAnalysisSessionFromCloudFile(fileID: UUID) async throws -> AnalysisSession {
        guard let file = cloudFiles.first(where: { $0.id == fileID }) else {
            throw CloudFilesStoreError.fileNotFound
        }
        if let linkedID = file.linkedAnalysisSessionID,
           let existing = analysisSessions.first(where: { $0.id == linkedID }) {
            activeAnalysisSessionID = existing.id
            return existing
        }
        throw CloudFilesStoreError.noLocalVideoCache
    }

    func attachAnalysisSession(_ sessionID: UUID, toCloudFileID fileID: UUID) async throws {
        guard let index = cloudFiles.firstIndex(where: { $0.id == fileID }) else {
            throw CloudFilesStoreError.fileNotFound
        }
        cloudFiles[index].linkedAnalysisSessionID = sessionID
        cloudFiles[index].updatedAt = Date()
        guard let backendID = cloudFiles[index].backendID else {
            throw CloudFilesStoreError.backendIdentifierMissing
        }
        let dto = try await cloudFileSyncService.updateFile(
            fileID: backendID,
            request: UpdateCloudFileRequest(
                name: nil,
                tags: nil,
                visibility: nil,
                sharedUserIDs: nil,
                moduleHint: nil,
                linkedAnalysisSessionID: sessionID.uuidString,
                linkedAnalysisClipID: cloudFiles[index].linkedAnalysisClipID?.uuidString,
                linkedTacticsScenarioID: cloudFiles[index].linkedTacticsScenarioID?.uuidString,
                linkedTrainingPlanID: cloudFiles[index].linkedTrainingPlanID?.uuidString
            )
        )
        upsertCloudFile(mapCloudFile(dto: dto))
    }

    func clipReferenceForFileOpen(clipID: UUID) -> MessengerClipReference? {
        guard let clip = analysisClips.first(where: { $0.id == clipID }),
              let session = analysisSessions.first(where: { $0.id == clip.sessionID }),
              let asset = analysisVideoAssets.first(where: { $0.id == clip.videoAssetID }) else {
            return nil
        }

        return MessengerClipReference(
            backendClipID: clip.backendClipID ?? "",
            backendAnalysisSessionID: session.backendSessionID ?? "",
            backendVideoAssetID: asset.backendVideoID ?? "",
            clipID: clip.id,
            analysisSessionID: session.id,
            videoAssetID: clip.videoAssetID,
            clipName: clip.name,
            timeStart: clip.startSeconds,
            timeEnd: clip.endSeconds,
            matchID: session.matchID
        )
    }

    func upsertClipCloudFileReference(_ clip: AnalysisClip) {
        let clipsFolderID = resolveDefaultFolderID(for: .clip)
        if let index = cloudFiles.firstIndex(where: { $0.linkedAnalysisClipID == clip.id }) {
            cloudFiles[index].name = clip.name
            cloudFiles[index].updatedAt = Date()
            cloudFiles[index].type = .clip
            cloudFiles[index].folderID = clipsFolderID
            cloudFiles[index].moduleHint = .analysis
            cloudFiles[index].deletedAt = nil
            syncLegacyFilesList()
            return
        }

        let file = CloudFile(
            id: UUID(),
            backendID: nil,
            teamID: activeCloudTeamID(),
            ownerUserID: activeCloudUserID(),
            name: clip.name,
            originalName: clip.name,
            type: .clip,
            mimeType: "application/x-pitchinsights-clip",
            sizeBytes: 0,
            createdAt: Date(),
            updatedAt: Date(),
            folderID: clipsFolderID,
            folderBackendID: cloudFolders.first(where: { $0.id == clipsFolderID })?.backendID,
            tags: ["clip"],
            moduleHint: .analysis,
            visibility: .teamWide,
            sharedUserIDs: [],
            checksum: nil,
            uploadStatus: .ready,
            deletedAt: nil,
            localCacheRelativePath: nil,
            linkedAnalysisSessionID: clip.sessionID,
            linkedAnalysisClipID: clip.id,
            linkedTacticsScenarioID: nil,
            linkedTrainingPlanID: nil
        )
        cloudFiles.insert(file, at: 0)
        syncLegacyFilesList()
    }

    func removeClipCloudFileReference(_ clipID: UUID) {
        cloudFiles.removeAll { $0.linkedAnalysisClipID == clipID }
        syncLegacyFilesList()
    }

    func upsertTrainingPlanCloudFileReference(_ plan: TrainingPlan) {
        let folderID = resolveDefaultFolderID(for: .trainingplan)
        if let index = cloudFiles.firstIndex(where: { $0.linkedTrainingPlanID == plan.id }) {
            cloudFiles[index].name = plan.title
            cloudFiles[index].updatedAt = Date()
            cloudFiles[index].type = .trainingplan
            cloudFiles[index].folderID = folderID
            cloudFiles[index].moduleHint = .training
            cloudFiles[index].deletedAt = nil
            syncLegacyFilesList()
            return
        }

        cloudFiles.insert(
            CloudFile(
                id: UUID(),
                backendID: nil,
                teamID: activeCloudTeamID(),
                ownerUserID: activeCloudUserID(),
                name: plan.title,
                originalName: plan.title,
                type: .trainingplan,
                mimeType: "application/x-pitchinsights-training",
                sizeBytes: 0,
                createdAt: Date(),
                updatedAt: Date(),
                folderID: folderID,
                folderBackendID: cloudFolders.first(where: { $0.id == folderID })?.backendID,
                tags: ["training"],
                moduleHint: .training,
                visibility: .teamWide,
                sharedUserIDs: [],
                checksum: nil,
                uploadStatus: .ready,
                deletedAt: nil,
                localCacheRelativePath: nil,
                linkedAnalysisSessionID: nil,
                linkedAnalysisClipID: nil,
                linkedTacticsScenarioID: nil,
                linkedTrainingPlanID: plan.id
            ),
            at: 0
        )
        syncLegacyFilesList()
    }

    func removeTrainingPlanCloudFileReference(planID: UUID) {
        cloudFiles.removeAll { $0.linkedTrainingPlanID == planID }
        syncLegacyFilesList()
    }

    func upsertTacticsScenarioCloudFileReference(_ scenario: TacticsScenario) {
        let folderID = resolveDefaultFolderID(for: .tacticboard)
        if let index = cloudFiles.firstIndex(where: { $0.linkedTacticsScenarioID == scenario.id }) {
            cloudFiles[index].name = scenario.name
            cloudFiles[index].updatedAt = Date()
            cloudFiles[index].type = .tacticboard
            cloudFiles[index].folderID = folderID
            cloudFiles[index].moduleHint = .tactics
            cloudFiles[index].deletedAt = nil
            syncLegacyFilesList()
            return
        }

        cloudFiles.insert(
            CloudFile(
                id: UUID(),
                backendID: nil,
                teamID: activeCloudTeamID(),
                ownerUserID: activeCloudUserID(),
                name: scenario.name,
                originalName: scenario.name,
                type: .tacticboard,
                mimeType: "application/x-pitchinsights-tactics",
                sizeBytes: 0,
                createdAt: Date(),
                updatedAt: Date(),
                folderID: folderID,
                folderBackendID: cloudFolders.first(where: { $0.id == folderID })?.backendID,
                tags: ["taktik"],
                moduleHint: .tactics,
                visibility: .teamWide,
                sharedUserIDs: [],
                checksum: nil,
                uploadStatus: .ready,
                deletedAt: nil,
                localCacheRelativePath: nil,
                linkedAnalysisSessionID: nil,
                linkedAnalysisClipID: nil,
                linkedTacticsScenarioID: scenario.id,
                linkedTrainingPlanID: nil
            ),
            at: 0
        )
        syncLegacyFilesList()
    }

    func removeTacticsScenarioCloudFileReference(scenarioID: UUID) {
        cloudFiles.removeAll { $0.linkedTacticsScenarioID == scenarioID }
        syncLegacyFilesList()
    }

    func resolveDefaultFolderID(for type: CloudFileType) -> UUID? {
        let name: String
        switch type {
        case .video: name = CloudSystemFolder.videos.rawValue
        case .clip: name = CloudSystemFolder.clips.rawValue
        case .tacticboard: name = CloudSystemFolder.tactics.rawValue
        case .trainingplan: name = CloudSystemFolder.trainings.rawValue
        case .image: name = CloudSystemFolder.images.rawValue
        case .document: name = CloudSystemFolder.documents.rawValue
        case .export, .analysisExport: name = CloudSystemFolder.exports.rawValue
        case .other: name = CloudSystemFolder.documents.rawValue
        }
        return cloudFolders.first(where: { $0.name == name && !$0.isDeleted })?.id
    }

    func activeCloudTeamID() -> String {
        if let teamID = messengerCurrentUser?.teamIDs.first, !teamID.isEmpty {
            return teamID
        }
        return "team.default"
    }

    func activeCloudUserID() -> String {
        messengerCurrentUser?.userID ?? "trainer.main"
    }

    private func makeCloudQueryRequest(filter: CloudFileFilterState, cursor: String?) -> CloudFilesQueryRequest {
        CloudFilesQueryRequest(
            teamID: activeCloudTeamID(),
            status: filter.status.rawValue,
            cursor: cursor,
            limit: 40,
            query: filter.query,
            type: nil,
            folderID: nil,
            ownerUserID: filter.ownerUserID,
            from: filter.fromDate,
            to: filter.toDate,
            minSizeBytes: filter.minSizeBytes,
            maxSizeBytes: filter.maxSizeBytes,
            sortField: filter.sortField.rawValue,
            sortDirection: filter.sortDirection.rawValue
        )
    }

    func applyCloudBootstrap(_ bootstrap: CloudFilesBootstrapDTO) {
        cloudUsage = TeamStorageUsage(
            teamID: bootstrap.usage.teamID,
            quotaBytes: bootstrap.usage.quotaBytes,
            usedBytes: bootstrap.usage.usedBytes,
            updatedAt: bootstrap.usage.updatedAt
        )
        cloudFolders = bootstrap.folders.map(mapCloudFolder(dto:))
        cloudFiles = bootstrap.files.map(mapCloudFile(dto:))
        cloudFileNextCursor = bootstrap.nextCursor
        if cloudActiveFolderID == nil {
            cloudActiveFolderID = cloudFolders.first(where: { $0.name == CloudSystemFolder.root.rawValue })?.id
        }
        ensureSystemFoldersExist()
    }

    private func ensureSystemFoldersExist() {
        if cloudFolders.isEmpty {
            return
        }
        guard let root = cloudFolders.first(where: { $0.parentID == nil && $0.name == CloudSystemFolder.root.rawValue }) else {
            return
        }
        for folder in CloudSystemFolder.allCases where folder != .root {
            if !cloudFolders.contains(where: { $0.name == folder.rawValue && !$0.isDeleted }) {
                cloudFolders.append(
                    CloudFolder(
                        id: UUID(),
                        backendID: nil,
                        teamID: activeCloudTeamID(),
                        parentID: root.id,
                        parentBackendID: root.backendID,
                        name: folder.rawValue,
                        createdAt: Date(),
                        updatedAt: Date(),
                        isSystemFolder: true,
                        isDeleted: false
                    )
                )
            }
        }
    }

    private func mapCloudFolder(dto: CloudFolderDTO) -> CloudFolder {
        let localID = cloudFolders.first(where: { $0.backendID == dto.id })?.id
            ?? UUID(uuidString: dto.id)
            ?? UUID()
        let parentLocalID = dto.parentID.flatMap { parent in
            cloudFolders.first(where: { $0.backendID == parent })?.id ?? UUID(uuidString: parent)
        }
        return CloudFolder(
            id: localID,
            backendID: dto.id,
            teamID: dto.teamID,
            parentID: parentLocalID,
            parentBackendID: dto.parentID,
            name: dto.name,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            isSystemFolder: dto.isSystemFolder,
            isDeleted: dto.isDeleted
        )
    }

    private func mapCloudFile(dto: CloudFileDTO) -> CloudFile {
        let localID = cloudFiles.first(where: { $0.backendID == dto.id })?.id
            ?? UUID(uuidString: dto.id)
            ?? UUID()
        let folderLocalID = dto.folderID.flatMap { backend in
            cloudFolders.first(where: { $0.backendID == backend })?.id
        }
        return CloudFile(
            id: localID,
            backendID: dto.id,
            teamID: dto.teamID,
            ownerUserID: dto.ownerUserID,
            name: dto.name,
            originalName: dto.originalName,
            type: CloudFileType(rawValue: dto.type) ?? .other,
            mimeType: dto.mimeType,
            sizeBytes: dto.sizeBytes,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            folderID: folderLocalID,
            folderBackendID: dto.folderID,
            tags: dto.tags,
            moduleHint: CloudModuleHint(rawValue: dto.moduleHint ?? "") ?? .generic,
            visibility: CloudFileVisibility(rawValue: dto.visibility ?? "") ?? .teamWide,
            sharedUserIDs: dto.sharedUserIDs ?? [],
            checksum: dto.checksum,
            uploadStatus: CloudUploadStatus(rawValue: dto.uploadStatus ?? "") ?? .ready,
            deletedAt: dto.deletedAt,
            localCacheRelativePath: cloudFiles.first(where: { $0.backendID == dto.id })?.localCacheRelativePath,
            linkedAnalysisSessionID: dto.linkedAnalysisSessionID.flatMap(UUID.init(uuidString:)),
            linkedAnalysisClipID: dto.linkedAnalysisClipID.flatMap(UUID.init(uuidString:)),
            linkedTacticsScenarioID: dto.linkedTacticsScenarioID.flatMap(UUID.init(uuidString:)),
            linkedTrainingPlanID: dto.linkedTrainingPlanID.flatMap(UUID.init(uuidString:))
        )
    }

    private func mergeCloudFiles(_ incoming: [CloudFile], reset: Bool) {
        if reset {
            cloudFiles = incoming
            return
        }
        for file in incoming {
            upsertCloudFile(file)
        }
    }

    private func upsertCloudFolder(_ folder: CloudFolder) {
        if let index = cloudFolders.firstIndex(where: { $0.id == folder.id || $0.backendID == folder.backendID }) {
            cloudFolders[index] = folder
        } else {
            cloudFolders.append(folder)
        }
    }

    private func upsertCloudFile(_ file: CloudFile) {
        if let index = cloudFiles.firstIndex(where: { $0.id == file.id || ($0.backendID != nil && $0.backendID == file.backendID) }) {
            cloudFiles[index] = file
        } else {
            cloudFiles.insert(file, at: 0)
        }
    }

    private func sortCloudFiles(
        _ items: [CloudFile],
        field: CloudFileSortField,
        direction: CloudSortDirection
    ) -> [CloudFile] {
        let sorted = items.sorted { lhs, rhs in
            let result: Bool
            switch field {
            case .name:
                result = lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .createdAt:
                result = lhs.createdAt < rhs.createdAt
            case .updatedAt:
                result = lhs.updatedAt < rhs.updatedAt
            case .sizeBytes:
                result = lhs.sizeBytes < rhs.sizeBytes
            }
            return direction == .ascending ? result : !result
        }
        return sorted
    }

    private func sanitizeTags(_ tags: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for tag in tags {
            let cleaned = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { continue }
            let key = cleaned.lowercased()
            if seen.contains(key) {
                continue
            }
            seen.insert(key)
            result.append(cleaned)
        }
        return result
    }

    private func updateUploadProgress(
        progressID: UUID,
        uploadedBytes: Int64,
        state: CloudUploadStatus,
        message: String?
    ) {
        guard let index = cloudUploads.firstIndex(where: { $0.id == progressID }) else { return }
        cloudUploads[index].uploadedBytes = uploadedBytes
        cloudUploads[index].state = state
        cloudUploads[index].message = message
    }

    func syncLegacyFilesList() {
        files = cloudFiles
            .filter { $0.deletedAt == nil }
            .map { file in
                FileItem(name: file.name, category: file.type.title)
            }
    }
}
