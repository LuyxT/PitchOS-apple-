import Foundation

@MainActor
extension AppDataStore {
    func bootstrapMessenger() async {
        guard AppConfiguration.messagingEnabled else {
            messengerConnectionState = .disconnected
            messengerChats = []
            messengerArchivedChats = []
            messengerMessagesByChat = [:]
            messengerSearchResults = []
            messengerChatNextCursor = nil
            messengerMessageNextCursorByChat = [:]
            messengerRealtimeService.disconnect()
            return
        }

        messengerOutboxItems = (try? messengerOutboxStore.loadItems()) ?? []
        messengerOutboxCount = messengerOutboxItems.count
        startMessengerOutboxRetryLoop()

        do {
            let me = try await messengerSyncService.fetchAuthMe()
            let primaryMembership = me.clubMemberships.first
            let roleValue = primaryMembership?.role ?? "trainer"
            let clubID = primaryMembership?.organizationId ?? "club.main"
            let teamIDs = me.clubMemberships.compactMap { $0.teamId }
            messengerCurrentUser = MessengerCurrentUser(
                userID: me.id,
                displayName: me.email,
                role: parseMessengerRole(roleValue),
                clubID: clubID,
                teamIDs: teamIDs
            )
            if messengerUserDirectory.isEmpty {
                buildMessengerDirectoryFromPlayers()
            }
            await loadChats(cursor: nil, includeArchived: false, query: nil)
            await connectMessengerRealtime()
            await processMessengerOutboxQueue()
        } catch {
            if isConnectivityFailure(error) {
                messengerConnectionState = .failed(error.localizedDescription)
            } else {
                print("[client] bootstrapMessenger: endpoint not available — \(error.localizedDescription)")
                messengerConnectionState = .disconnected
            }
        }
    }

    func reconnectMessengerRealtimeIfNeeded() async {
        guard AppConfiguration.messagingEnabled else { return }
        if case .connected = messengerConnectionState {
            return
        }
        await connectMessengerRealtime()
    }

    func loadChats(cursor: String?, includeArchived: Bool, query: String?) async {
        do {
            let page = try await messengerSyncService.fetchChats(
                cursor: cursor,
                limit: 40,
                includeArchived: includeArchived,
                query: query
            )
            let mapped = page.items.map(mapMessengerChat(dto:))
            mergeChats(mapped, reset: cursor == nil, archived: includeArchived)
            messengerChatNextCursor = page.nextCursor
        } catch {
            print("[client] loadChats error: \(error.localizedDescription)")
        }
    }

    func loadMessages(chatID: UUID, before: Date?, limit: Int) async {
        guard let chat = messengerChatByLocalID(chatID) else { return }

        let cursor: String?
        if let before {
            cursor = ISO8601DateFormatter().string(from: before)
        } else {
            cursor = messengerMessageNextCursorByChat[chatID]
        }

        do {
            let page = try await messengerSyncService.fetchMessages(chatID: chat.backendChatID, cursor: cursor, limit: limit)
            let mapped = page.items.map { mapMessengerMessage(dto: $0, fallbackChatID: chatID) }
            mergeMessages(mapped, chatID: chatID, reset: before == nil && cursor == nil)
            messengerMessageNextCursorByChat[chatID] = page.nextCursor
        } catch {
            print("[client] loadMessages error: \(error.localizedDescription)")
        }
    }

    func createDirectChat(participantID: String) async throws {
        let dto = try await messengerSyncService.createDirectChat(participantUserID: participantID)
        let chat = mapMessengerChat(dto: dto)
        upsertChat(chat)
    }

    func createGroupChat(
        title: String,
        participantUserIDs: [String],
        writePermission: MessengerChatPermission,
        temporaryUntil: Date?
    ) async throws {
        let dto = try await messengerSyncService.createGroupChat(
            title: title,
            participantUserIDs: participantUserIDs,
            writePermission: writePermission,
            temporaryUntil: temporaryUntil
        )
        let chat = mapMessengerChat(dto: dto)
        upsertChat(chat)
    }

    func updateChatPermissions(chatID: UUID, permission: MessengerChatPermission) async throws {
        guard let chat = messengerChatByLocalID(chatID) else { return }
        updateLocalChat(chatID: chatID) { mutable in
            mutable.writePermission = permission
        }
        let updated = try await messengerSyncService.updateChat(
            chatID: chat.backendChatID,
            writePolicy: permission
        )
        upsertChat(mapMessengerChat(dto: updated))
    }

    func pinChat(_ chatID: UUID) async {
        guard let chat = messengerChatByLocalID(chatID) else { return }
        let newValue = !chat.pinned
        updateLocalChat(chatID: chatID) { mutable in
            mutable.pinned = newValue
        }
        do {
            let dto = try await messengerSyncService.updateChat(chatID: chat.backendChatID, pinned: newValue)
            upsertChat(mapMessengerChat(dto: dto))
        } catch {
            print("[client] pinChat error: \(error.localizedDescription)")
        }
    }

    func muteChat(_ chatID: UUID) async {
        guard let chat = messengerChatByLocalID(chatID) else { return }
        let newValue = !chat.muted
        updateLocalChat(chatID: chatID) { mutable in
            mutable.muted = newValue
        }
        do {
            let dto = try await messengerSyncService.updateChat(chatID: chat.backendChatID, muted: newValue)
            upsertChat(mapMessengerChat(dto: dto))
        } catch {
            print("[client] muteChat error: \(error.localizedDescription)")
        }
    }

    func archiveChat(_ chatID: UUID) async {
        guard let chat = messengerChatByLocalID(chatID) else { return }
        let targetArchived = !chat.archived

        if targetArchived {
            messengerChats.removeAll { $0.id == chatID }
            var archived = chat
            archived.archived = true
            messengerArchivedChats.insert(archived, at: 0)
        } else {
            messengerArchivedChats.removeAll { $0.id == chatID }
            var active = chat
            active.archived = false
            messengerChats.insert(active, at: 0)
        }
        do {
            let dto: MessengerChatDTO
            if targetArchived {
                dto = try await messengerSyncService.archiveChat(chatID: chat.backendChatID)
            } else {
                dto = try await messengerSyncService.unarchiveChat(chatID: chat.backendChatID)
            }
            upsertChat(mapMessengerChat(dto: dto))
        } catch {
            print("[client] archiveChat error: \(error.localizedDescription)")
        }
    }

    func sendText(chatID: UUID, text: String, contextLabel: String?) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let me = messengerCurrentUser else { return }

        let message = MessengerMessage(
            chatID: chatID,
            senderUserID: me.userID,
            senderName: me.displayName,
            type: .text,
            text: trimmed,
            contextLabel: contextLabel,
            status: .queued,
            isMine: true
        )
        appendLocalMessage(message)
        enqueueOutbox(
            localMessageID: message.id,
            chatID: chatID,
            payload: MessengerOutboxPayload(
                kind: .text,
                text: trimmed,
                contextLabel: contextLabel,
                attachment: nil,
                clipReference: nil
            )
        )
        await processMessengerOutboxQueue()
    }

    func sendMedia(chatID: UUID, fileURL: URL, contextLabel: String?) async {
        guard let me = messengerCurrentUser else { return }
        do {
            let inferredType = cloudFileStore.inferFileType(for: fileURL)
            let preferredType: CloudFileType = inferredType == .image ? .image : .video
            let cloudFile = try await uploadCloudFile(
                from: fileURL,
                preferredType: preferredType,
                moduleHint: .messenger,
                folderID: resolveDefaultFolderID(for: preferredType),
                tags: ["messenger"],
                visibility: .restricted
            )
            let kind: MessengerAttachmentKind = preferredType == .image ? .image : .video
            let attachment = MessengerAttachment(
                backendMediaID: cloudFile.backendID,
                kind: kind,
                filename: cloudFile.name,
                mimeType: cloudFile.mimeType,
                fileSize: cloudFile.sizeBytes,
                sha256: cloudFile.checksum,
                localRelativePath: cloudFile.localCacheRelativePath,
                uploadState: .sent
            )

            let message = MessengerMessage(
                chatID: chatID,
                senderUserID: me.userID,
                senderName: me.displayName,
                type: kind == .image ? .image : .video,
                text: "",
                contextLabel: contextLabel,
                attachment: attachment,
                status: .queued,
                isMine: true
            )
            appendLocalMessage(message)
            enqueueOutbox(
                localMessageID: message.id,
                chatID: chatID,
                payload: MessengerOutboxPayload(
                    kind: .media,
                    text: "",
                    contextLabel: contextLabel,
                    attachment: attachment,
                    clipReference: nil
                )
            )
            await processMessengerOutboxQueue()
        } catch {
            print("[client] sendMedia error: \(error.localizedDescription)")
        }
    }

    func sendCloudFileReference(chatID: UUID, cloudFileID: UUID, contextLabel: String?) async {
        guard let me = messengerCurrentUser else { return }
        guard let cloudFile = cloudFiles.first(where: { $0.id == cloudFileID }) else { return }

        let type: MessengerMessageType
        let attachmentKind: MessengerAttachmentKind
        switch cloudFile.type {
        case .image:
            type = .image
            attachmentKind = .image
        default:
            type = .video
            attachmentKind = .video
        }

        let attachment = MessengerAttachment(
            backendMediaID: cloudFile.backendID,
            kind: attachmentKind,
            filename: cloudFile.name,
            mimeType: cloudFile.mimeType,
            fileSize: cloudFile.sizeBytes,
            sha256: cloudFile.checksum,
            localRelativePath: cloudFile.localCacheRelativePath,
            uploadState: .sent
        )

        let message = MessengerMessage(
            chatID: chatID,
            senderUserID: me.userID,
            senderName: me.displayName,
            type: type,
            text: "",
            contextLabel: contextLabel,
            attachment: attachment,
            status: .queued,
            isMine: true
        )
        appendLocalMessage(message)
        enqueueOutbox(
            localMessageID: message.id,
            chatID: chatID,
            payload: MessengerOutboxPayload(
                kind: .media,
                text: "",
                contextLabel: contextLabel,
                attachment: attachment,
                clipReference: nil
            )
        )
        await processMessengerOutboxQueue()
    }

    func shareAnalysisClipToChat(chatID: UUID, clipID: UUID, contextLabel: String?) async {
        guard let clip = analysisClips.first(where: { $0.id == clipID }),
              let session = analysisSessions.first(where: { $0.id == clip.sessionID }),
              let asset = analysisVideoAssets.first(where: { $0.id == clip.videoAssetID }),
              let me = messengerCurrentUser else { return }

        let ref = MessengerClipReference(
            backendClipID: clip.backendClipID ?? "",
            backendAnalysisSessionID: session.backendSessionID ?? "",
            backendVideoAssetID: asset.backendVideoID ?? "",
            clipID: clip.id,
            analysisSessionID: session.id,
            videoAssetID: asset.id,
            clipName: clip.name,
            timeStart: clip.startSeconds,
            timeEnd: clip.endSeconds,
            matchID: session.matchID
        )

        let message = MessengerMessage(
            chatID: chatID,
            senderUserID: me.userID,
            senderName: me.displayName,
            type: .analysisClipReference,
            text: "",
            contextLabel: contextLabel,
            clipReference: ref,
            status: .queued,
            isMine: true
        )
        appendLocalMessage(message)
        enqueueOutbox(
            localMessageID: message.id,
            chatID: chatID,
            payload: MessengerOutboxPayload(
                kind: .clipReference,
                text: "",
                contextLabel: contextLabel,
                attachment: nil,
                clipReference: ref
            )
        )
        await processMessengerOutboxQueue()
    }

    func markChatRead(chatID: UUID, messageID: UUID?) async {
        updateLocalChat(chatID: chatID) { mutable in
            mutable.unreadCount = 0
        }
        guard let chat = messengerChatByLocalID(chatID) else { return }
        let backendMessageID = messageID.flatMap { localID in
            messengerMessagesByChat[chatID]?.first(where: { $0.id == localID })?.backendMessageID
        }
        do {
            try await messengerSyncService.markRead(chatID: chat.backendChatID, lastReadMessageID: backendMessageID)
        } catch {
            print("[client] markChatRead error: \(error.localizedDescription)")
        }
    }

    func searchMessenger(query: String, includeArchived: Bool) async {
        let local = messengerSearchService.localSearch(
            query: query,
            includeArchived: includeArchived,
            chats: includeArchived ? messengerArchivedChats : messengerChats,
            messagesByChat: messengerMessagesByChat,
            analysisClips: analysisClips,
            analysisMarkers: analysisMarkers
        )
        messengerSearchResults = local

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let remote = try await messengerSyncService.search(query: trimmed, cursor: nil, limit: 30, includeArchived: includeArchived)
            let mapped = remote.items.map { dto in
                MessengerSearchResult(
                    id: UUID(),
                    type: parseSearchType(dto.type),
                    chatID: dto.chatID.flatMap(localChatID(forBackendID:)),
                    messageID: dto.messageID.flatMap(localMessageID(forBackendID:)),
                    title: dto.title,
                    subtitle: dto.subtitle,
                    occurredAt: dto.occurredAt
                )
            }
            messengerSearchResults = mergeSearch(local: local, remote: mapped)
        } catch {
            print("[client] searchMessenger error: \(error.localizedDescription)")
        }
    }

    func retryMessage(localMessageID: UUID) async {
        guard let (chatID, existingMessage) = findMessage(localMessageID: localMessageID) else { return }
        updateMessage(chatID: chatID, messageID: localMessageID) { mutable in
            mutable.status = .queued
            mutable.updatedAt = Date()
        }

        if let index = messengerOutboxItems.firstIndex(where: { $0.localMessageID == localMessageID }) {
            messengerOutboxItems[index].attemptCount = 0
            messengerOutboxItems[index].nextRetryAt = nil
            messengerOutboxItems[index].lastError = nil
        } else {
            let payload = payloadFromMessage(existingMessage)
            enqueueOutbox(localMessageID: localMessageID, chatID: chatID, payload: payload)
        }

        persistOutbox()
        await processMessengerOutboxQueue()
    }

    func deleteMessage(localMessageID: UUID, chatID: UUID) async {
        let backendMessageID = messengerMessagesByChat[chatID]?.first(where: { $0.id == localMessageID })?.backendMessageID
        messengerMessagesByChat[chatID]?.removeAll { $0.id == localMessageID }
        messengerOutboxItems.removeAll { $0.localMessageID == localMessageID }
        persistOutbox()
        updateOutboxCount()
        guard let chat = messengerChatByLocalID(chatID), let backendMessageID else { return }
        do {
            try await messengerSyncService.deleteMessage(chatID: chat.backendChatID, messageID: backendMessageID)
        } catch {
            print("[client] deleteMessage error: \(error.localizedDescription)")
        }
    }

    private func connectMessengerRealtime() async {
        guard AppConfiguration.messagingEnabled else {
            messengerRealtimeService.disconnect()
            messengerConnectionState = .disconnected
            return
        }

        let baseURL = AppConfiguration.baseURL
        do {
            let token = try await messengerSyncService.fetchRealtimeToken()
            messengerRealtimeService.connect(baseURL: baseURL, token: token.token)
        } catch {
            messengerConnectionState = .failed(error.localizedDescription)
            scheduleMessengerRealtimeReconnect()
        }
    }

    func configureMessengerRealtimeCallbacks() {
        messengerRealtimeService.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.messengerConnectionState = state
                if case .connected = state {
                    self?.messengerReconnectAttempt = 0
                }
            }
        }

        messengerRealtimeService.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.applyMessengerRealtimeEvent(event)
            }
        }

        messengerRealtimeService.onUnexpectedDisconnect = { [weak self] in
            Task { @MainActor in
                self?.scheduleMessengerRealtimeReconnect()
            }
        }
    }

    private func scheduleMessengerRealtimeReconnect() {
        messengerRealtimeReconnectTask?.cancel()
        let delay = nextReconnectDelaySeconds()
        messengerRealtimeReconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.reconnectMessengerRealtimeIfNeeded()
        }
    }

    private func nextReconnectDelaySeconds() -> Double {
        let seconds = min(pow(2.0, Double(messengerReconnectAttempt)), 30.0)
        messengerReconnectAttempt += 1
        let jitter = Double.random(in: 0..<0.35)
        return min(30.0, seconds + jitter)
    }

    private func applyMessengerRealtimeEvent(_ event: MessengerRealtimeEventDTO) {
        messengerRealtimeCursor = event.eventCursor
        switch event.type {
        case "chat.updated":
            if let chat = event.chat {
                upsertChat(mapMessengerChat(dto: chat))
            }
        case "message.created", "message.updated":
            if let message = event.message {
                let localChatID = localChatID(forBackendID: message.chatID) ?? UUID()
                let mapped = mapMessengerMessage(dto: message, fallbackChatID: localChatID)
                upsertMessage(mapped)
            }
        case "message.deleted":
            if let backendID = event.messageID {
                removeMessageByBackendID(backendID)
            }
        case "receipt.updated":
            if let message = event.message {
                let localChatID = localChatID(forBackendID: message.chatID) ?? UUID()
                let mapped = mapMessengerMessage(dto: message, fallbackChatID: localChatID)
                upsertMessage(mapped)
            }
        default:
            break
        }
    }

    private func startMessengerOutboxRetryLoop() {
        messengerOutboxRetryTask?.cancel()
        messengerOutboxRetryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.processMessengerOutboxQueue()
            }
        }
    }

    private func processMessengerOutboxQueue() async {
        guard !messengerOutboxItems.isEmpty else { return }
        let now = Date()
        let due = messengerOutboxItems
            .filter { ($0.nextRetryAt ?? .distantPast) <= now }
            .map(\.id)

        for id in due {
            guard let index = messengerOutboxItems.firstIndex(where: { $0.id == id }) else { continue }
            var item = messengerOutboxItems[index]
            do {
                let sent = try await dispatchOutboxItem(item)
                upsertMessage(sent)
                messengerOutboxItems.removeAll { $0.id == id }
            } catch {
                item.attemptCount += 1
                item.lastError = error.localizedDescription
                item.nextRetryAt = Date().addingTimeInterval(min(pow(2.0, Double(item.attemptCount)), 30))
                messengerOutboxItems[index] = item
                updateMessage(chatID: item.chatID, messageID: item.localMessageID) { mutable in
                    mutable.status = .failed
                    mutable.updatedAt = Date()
                }
            }
        }

        persistOutbox()
        updateOutboxCount()
    }

    private func dispatchOutboxItem(_ item: MessengerOutboxItem) async throws -> MessengerMessage {
        guard let chat = messengerChatByLocalID(item.chatID) else {
            throw NSError(domain: "Messenger", code: 1, userInfo: [NSLocalizedDescriptionKey: "Chat nicht gefunden"])
        }

        switch item.payload.kind {
        case .text:
            let dto = try await messengerSyncService.sendMessage(
                chatID: chat.backendChatID,
                request: CreateMessageRequest(
                    type: MessengerMessageType.text.rawValue,
                    text: item.payload.text ?? "",
                    contextLabel: item.payload.contextLabel,
                    attachmentID: nil,
                    clipReference: nil
                )
            )
            var mapped = mapMessengerMessage(dto: dto, fallbackChatID: item.chatID)
            mapped.id = item.localMessageID
            return mapped

        case .media:
            guard var attachment = item.payload.attachment else {
                throw NSError(domain: "Messenger", code: 3, userInfo: [NSLocalizedDescriptionKey: "Anhang fehlt"])
            }
            if attachment.backendMediaID == nil {
                guard let relative = attachment.localRelativePath,
                      let localURL = messengerMediaStore.fileURL(for: relative) else {
                    throw NSError(domain: "Messenger", code: 4, userInfo: [NSLocalizedDescriptionKey: "Anhang nicht verfügbar"])
                }
                let persisted = PersistedMessengerMedia(
                    mediaID: attachment.id,
                    originalFilename: attachment.filename,
                    localRelativePath: relative,
                    localURL: localURL,
                    fileSize: attachment.fileSize,
                    mimeType: attachment.mimeType,
                    sha256: attachment.sha256 ?? "",
                    kind: attachment.kind
                )
                let completed = try await messengerSyncService.uploadMedia(persisted)
                attachment.backendMediaID = completed.mediaID
                attachment.uploadState = .sent
                updateMessage(chatID: item.chatID, messageID: item.localMessageID) { mutable in
                    mutable.attachment = attachment
                    mutable.status = .uploading
                }
            }

            let dto = try await messengerSyncService.sendMessage(
                chatID: chat.backendChatID,
                request: CreateMessageRequest(
                    type: attachment.kind == .image ? MessengerMessageType.image.rawValue : MessengerMessageType.video.rawValue,
                    text: "",
                    contextLabel: item.payload.contextLabel,
                    attachmentID: attachment.backendMediaID,
                    clipReference: nil
                )
            )
            var mapped = mapMessengerMessage(dto: dto, fallbackChatID: item.chatID)
            mapped.id = item.localMessageID
            return mapped

        case .clipReference:
            guard let ref = item.payload.clipReference else {
                throw NSError(domain: "Messenger", code: 5, userInfo: [NSLocalizedDescriptionKey: "Clip-Referenz fehlt"])
            }
            let dtoRef = MessengerClipReferenceDTO(
                clipID: ref.backendClipID,
                analysisSessionID: ref.backendAnalysisSessionID,
                videoAssetID: ref.backendVideoAssetID,
                clipName: ref.clipName,
                timeStart: ref.timeStart,
                timeEnd: ref.timeEnd,
                matchID: ref.matchID
            )
            let dto = try await messengerSyncService.sendMessage(
                chatID: chat.backendChatID,
                request: CreateMessageRequest(
                    type: MessengerMessageType.analysisClipReference.rawValue,
                    text: "",
                    contextLabel: item.payload.contextLabel,
                    attachmentID: nil,
                    clipReference: dtoRef
                )
            )
            var mapped = mapMessengerMessage(dto: dto, fallbackChatID: item.chatID)
            mapped.id = item.localMessageID
            return mapped
        }
    }

    private func enqueueOutbox(localMessageID: UUID, chatID: UUID, payload: MessengerOutboxPayload) {
        messengerOutboxItems.append(
            MessengerOutboxItem(
                id: UUID(),
                localMessageID: localMessageID,
                chatID: chatID,
                createdAt: Date(),
                payload: payload,
                attemptCount: 0,
                nextRetryAt: nil,
                lastError: nil
            )
        )
        persistOutbox()
        updateOutboxCount()
    }

    private func persistOutbox() {
        try? messengerOutboxStore.saveItems(messengerOutboxItems)
    }

    private func updateOutboxCount() {
        messengerOutboxCount = messengerOutboxItems.count
    }

    private func appendLocalMessage(_ message: MessengerMessage) {
        var messages = messengerMessagesByChat[message.chatID] ?? []
        messages.append(message)
        messages.sort { $0.createdAt < $1.createdAt }
        messengerMessagesByChat[message.chatID] = messages
        updateLocalChat(chatID: message.chatID) { mutable in
            mutable.lastMessagePreview = previewText(for: message)
            mutable.lastMessageAt = message.createdAt
        }
    }

    private func mergeMessages(_ incoming: [MessengerMessage], chatID: UUID, reset: Bool) {
        var current = reset ? [] : (messengerMessagesByChat[chatID] ?? [])
        for message in incoming {
            if let index = current.firstIndex(where: { $0.backendMessageID == message.backendMessageID || $0.id == message.id }) {
                current[index] = message
            } else {
                current.append(message)
            }
        }
        current.sort { $0.createdAt < $1.createdAt }
        messengerMessagesByChat[chatID] = current
        if let latest = current.last {
            updateLocalChat(chatID: chatID) { mutable in
                mutable.lastMessagePreview = previewText(for: latest)
                mutable.lastMessageAt = latest.createdAt
            }
        }
    }

    private func mergeChats(_ chats: [MessengerChat], reset: Bool, archived: Bool) {
        var target = archived ? messengerArchivedChats : messengerChats
        if reset {
            target = chats
        } else {
            for chat in chats {
                if let index = target.firstIndex(where: { $0.backendChatID == chat.backendChatID || $0.id == chat.id }) {
                    target[index] = chat
                } else {
                    target.append(chat)
                }
            }
        }
        target.sort { lhs, rhs in
            if lhs.pinned != rhs.pinned {
                return lhs.pinned && !rhs.pinned
            }
            return (lhs.lastMessageAt ?? lhs.updatedAt) > (rhs.lastMessageAt ?? rhs.updatedAt)
        }
        if archived {
            messengerArchivedChats = target
        } else {
            messengerChats = target
        }
    }

    private func upsertChat(_ chat: MessengerChat) {
        if chat.archived {
            messengerChats.removeAll { $0.backendChatID == chat.backendChatID || $0.id == chat.id }
            if let index = messengerArchivedChats.firstIndex(where: { $0.backendChatID == chat.backendChatID || $0.id == chat.id }) {
                messengerArchivedChats[index] = chat
            } else {
                messengerArchivedChats.insert(chat, at: 0)
            }
        } else {
            messengerArchivedChats.removeAll { $0.backendChatID == chat.backendChatID || $0.id == chat.id }
            if let index = messengerChats.firstIndex(where: { $0.backendChatID == chat.backendChatID || $0.id == chat.id }) {
                messengerChats[index] = chat
            } else {
                messengerChats.insert(chat, at: 0)
            }
        }
    }

    private func upsertMessage(_ message: MessengerMessage) {
        var messages = messengerMessagesByChat[message.chatID] ?? []
        if let index = messages.firstIndex(where: { $0.backendMessageID == message.backendMessageID || $0.id == message.id }) {
            messages[index] = message
        } else {
            messages.append(message)
        }
        messages.sort { $0.createdAt < $1.createdAt }
        messengerMessagesByChat[message.chatID] = messages
        updateLocalChat(chatID: message.chatID) { mutable in
            mutable.lastMessagePreview = previewText(for: message)
            mutable.lastMessageAt = message.createdAt
        }
    }

    private func removeMessageByBackendID(_ backendID: String) {
        for (chatID, messages) in messengerMessagesByChat {
            let filtered = messages.filter { $0.backendMessageID != backendID }
            messengerMessagesByChat[chatID] = filtered
        }
    }

    private func updateMessage(chatID: UUID, messageID: UUID, mutate: (inout MessengerMessage) -> Void) {
        guard var messages = messengerMessagesByChat[chatID],
              let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        var mutable = messages[index]
        mutate(&mutable)
        messages[index] = mutable
        messengerMessagesByChat[chatID] = messages
    }

    private func updateLocalChat(chatID: UUID, mutate: (inout MessengerChat) -> Void) {
        if let index = messengerChats.firstIndex(where: { $0.id == chatID }) {
            var mutable = messengerChats[index]
            mutate(&mutable)
            messengerChats[index] = mutable
        } else if let index = messengerArchivedChats.firstIndex(where: { $0.id == chatID }) {
            var mutable = messengerArchivedChats[index]
            mutate(&mutable)
            messengerArchivedChats[index] = mutable
        }
    }

    private func messengerChatByLocalID(_ localID: UUID) -> MessengerChat? {
        messengerChats.first(where: { $0.id == localID }) ?? messengerArchivedChats.first(where: { $0.id == localID })
    }

    private func localChatID(forBackendID backendID: String) -> UUID? {
        messengerChats.first(where: { $0.backendChatID == backendID })?.id
            ?? messengerArchivedChats.first(where: { $0.backendChatID == backendID })?.id
    }

    private func localMessageID(forBackendID backendID: String) -> UUID? {
        for messages in messengerMessagesByChat.values {
            if let found = messages.first(where: { $0.backendMessageID == backendID }) {
                return found.id
            }
        }
        return nil
    }

    private func findMessage(localMessageID: UUID) -> (UUID, MessengerMessage)? {
        for (chatID, messages) in messengerMessagesByChat {
            if let message = messages.first(where: { $0.id == localMessageID }) {
                return (chatID, message)
            }
        }
        return nil
    }

    private func payloadFromMessage(_ message: MessengerMessage) -> MessengerOutboxPayload {
        MessengerOutboxPayload(
            kind: message.type == .analysisClipReference ? .clipReference : (message.attachment == nil ? .text : .media),
            text: message.text,
            contextLabel: message.contextLabel,
            attachment: message.attachment,
            clipReference: message.clipReference
        )
    }

    private func mapMessengerChat(dto: MessengerChatDTO) -> MessengerChat {
        let localID = localChatID(forBackendID: dto.id) ?? UUID()
        let participants = dto.participants.map { p in
            MessengerParticipant(
                id: UUID(),
                backendUserID: p.userID,
                displayName: p.displayName,
                role: parseMessengerRole(p.role),
                playerID: p.playerID,
                mutedUntil: p.mutedUntil,
                canWrite: p.canWrite,
                joinedAt: p.joinedAt
            )
        }
        mergeIntoUserDirectory(participants)
        return MessengerChat(
            id: localID,
            backendChatID: dto.id,
            title: dto.title,
            type: dto.type == "group" ? .group : .direct,
            participants: participants,
            lastMessagePreview: dto.lastMessagePreview ?? "",
            lastMessageAt: dto.lastMessageAt,
            unreadCount: dto.unreadCount,
            pinned: dto.pinned,
            muted: dto.muted,
            archived: dto.archived,
            writePermission: parseChatPermission(dto.writePermission),
            temporaryUntil: dto.temporaryUntil,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    private func mapMessengerMessage(dto: MessengerMessageDTO, fallbackChatID: UUID) -> MessengerMessage {
        let localChatID = localChatID(forBackendID: dto.chatID) ?? fallbackChatID
        let attachment = dto.attachment.map { a in
            MessengerAttachment(
                backendMediaID: a.mediaID,
                kind: a.kind == "video" ? .video : .image,
                filename: a.filename,
                mimeType: a.mimeType,
                fileSize: a.fileSize,
                uploadState: .sent
            )
        }

        let clipReference = dto.clipReference.map { c in
            MessengerClipReference(
                backendClipID: c.clipID,
                backendAnalysisSessionID: c.analysisSessionID,
                backendVideoAssetID: c.videoAssetID,
                clipID: analysisClips.first(where: { $0.backendClipID == c.clipID })?.id,
                analysisSessionID: analysisSessions.first(where: { $0.backendSessionID == c.analysisSessionID })?.id,
                videoAssetID: analysisVideoAssets.first(where: { $0.backendVideoID == c.videoAssetID })?.id,
                clipName: c.clipName,
                timeStart: c.timeStart,
                timeEnd: c.timeEnd,
                matchID: c.matchID
            )
        }

        return MessengerMessage(
            id: localMessageID(forBackendID: dto.id) ?? UUID(),
            backendMessageID: dto.id,
            chatID: localChatID,
            senderUserID: dto.senderUserID,
            senderName: dto.senderName,
            type: parseMessageType(dto.type),
            text: dto.text,
            contextLabel: dto.contextLabel,
            attachment: attachment,
            clipReference: clipReference,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            status: parseMessageStatus(dto.status),
            readBy: dto.readBy.map { MessengerReadReceipt(userID: $0.userID, userName: $0.userName, readAt: $0.readAt) },
            isMine: dto.senderUserID == messengerCurrentUser?.userID
        )
    }

    private func mergeIntoUserDirectory(_ participants: [MessengerParticipant]) {
        for participant in participants {
            if let index = messengerUserDirectory.firstIndex(where: { $0.backendUserID == participant.backendUserID }) {
                messengerUserDirectory[index] = participant
            } else {
                messengerUserDirectory.append(participant)
            }
        }
        messengerUserDirectory.sort { $0.displayName < $1.displayName }
    }

    private func parseMessengerRole(_ value: String) -> MessengerMembershipRole {
        value.lowercased() == "trainer" ? .trainer : .player
    }

    private func parseChatPermission(_ value: String) -> MessengerChatPermission {
        switch value.lowercased() {
        case "traineronly", "trainer_only", "trainer":
            return .trainerOnly
        case "custom":
            return .custom
        default:
            return .allMembers
        }
    }

    private func parseMessageType(_ value: String) -> MessengerMessageType {
        switch value.lowercased() {
        case "image":
            return .image
        case "video":
            return .video
        case "analysisclipreference", "analysis_clip_reference", "clip":
            return .analysisClipReference
        default:
            return .text
        }
    }

    private func parseMessageStatus(_ value: String) -> MessengerMessageStatus {
        switch value.lowercased() {
        case "uploading":
            return .uploading
        case "sent":
            return .sent
        case "delivered":
            return .delivered
        case "read":
            return .read
        case "failed":
            return .failed
        default:
            return .queued
        }
    }

    private func parseSearchType(_ value: String) -> MessengerSearchResultType {
        switch value.lowercased() {
        case "chat":
            return .chat
        case "analysisclip", "analysis_clip":
            return .analysisClip
        case "analysismarker", "analysis_marker":
            return .analysisMarker
        default:
            return .message
        }
    }

    private func mergeSearch(local: [MessengerSearchResult], remote: [MessengerSearchResult]) -> [MessengerSearchResult] {
        var combined = local
        for result in remote {
            if !combined.contains(where: { $0.type == result.type && $0.title == result.title && $0.subtitle == result.subtitle }) {
                combined.append(result)
            }
        }
        return combined.sorted { ($0.occurredAt ?? .distantPast) > ($1.occurredAt ?? .distantPast) }
    }

    private func previewText(for message: MessengerMessage) -> String {
        switch message.type {
        case .text:
            return message.text
        case .image:
            return "Bild"
        case .video:
            return "Video"
        case .analysisClipReference:
            return "Clip: \(message.clipReference?.clipName ?? "Analyse")"
        }
    }

    private func buildMessengerDirectoryFromPlayers() {
        var directory: [MessengerParticipant] = []
        if let me = messengerCurrentUser {
            directory.append(
                MessengerParticipant(
                    backendUserID: me.userID,
                    displayName: me.displayName,
                    role: me.role,
                    playerID: nil,
                    canWrite: true
                )
            )
        }
        messengerUserDirectory = directory
    }

    private func messengerSelfParticipant() -> MessengerParticipant? {
        guard let me = messengerCurrentUser else { return nil }
        return MessengerParticipant(
            backendUserID: me.userID,
            displayName: me.displayName,
            role: me.role,
            playerID: nil,
            canWrite: true
        )
    }
}
