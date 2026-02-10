import Foundation

enum MessengerSyncServiceError: LocalizedError {
    case invalidUploadURL

    var errorDescription: String? {
        switch self {
        case .invalidUploadURL:
            return "Ungültige Upload-URL."
        }
    }
}

final class MessengerSyncService {
    private let backend: BackendRepository

    init(backend: BackendRepository) {
        self.backend = backend
    }

    func fetchAuthMe() async throws -> AuthMeDTO {
        try await backend.fetchAuthMe()
    }

    func fetchChats(cursor: String?, limit: Int, includeArchived: Bool, query: String?) async throws -> MessengerChatsPageDTO {
        try await backend.fetchMessengerChats(
            cursor: cursor,
            limit: limit,
            includeArchived: includeArchived,
            query: query
        )
    }

    func createDirectChat(participantUserID: String) async throws -> MessengerChatDTO {
        try await backend.createDirectChat(CreateDirectChatRequest(participantUserID: participantUserID))
    }

    func createGroupChat(
        title: String,
        participantUserIDs: [String],
        writePermission: MessengerChatPermission,
        temporaryUntil: Date?
    ) async throws -> MessengerChatDTO {
        try await backend.createGroupChat(
            CreateGroupChatRequest(
                title: title,
                participantUserIDs: participantUserIDs,
                writePermission: writePermission.rawValue,
                temporaryUntil: temporaryUntil
            )
        )
    }

    func updateChat(
        chatID: String,
        name: String? = nil,
        muted: Bool? = nil,
        pinned: Bool? = nil,
        archived: Bool? = nil,
        writePolicy: MessengerChatPermission? = nil,
        temporaryUntil: Date? = nil
    ) async throws -> MessengerChatDTO {
        try await backend.updateChat(
            chatID: chatID,
            request: UpdateChatRequest(
                name: name,
                muted: muted,
                pinned: pinned,
                archived: archived,
                writePolicy: writePolicy?.rawValue,
                temporaryUntil: temporaryUntil
            )
        )
    }

    func archiveChat(chatID: String) async throws -> MessengerChatDTO {
        try await backend.archiveChat(chatID: chatID)
    }

    func unarchiveChat(chatID: String) async throws -> MessengerChatDTO {
        try await backend.unarchiveChat(chatID: chatID)
    }

    func fetchMessages(chatID: String, cursor: String?, limit: Int) async throws -> MessengerMessagesPageDTO {
        try await backend.fetchMessages(chatID: chatID, cursor: cursor, limit: limit)
    }

    func sendMessage(chatID: String, request: CreateMessageRequest) async throws -> MessengerMessageDTO {
        try await backend.sendMessage(chatID: chatID, request: request)
    }

    func deleteMessage(chatID: String, messageID: String) async throws {
        _ = try await backend.deleteMessage(chatID: chatID, messageID: messageID)
    }

    func markRead(chatID: String, lastReadMessageID: String?) async throws {
        _ = try await backend.markChatRead(chatID: chatID, request: MarkChatReadRequest(lastReadMessageID: lastReadMessageID))
    }

    func fetchReadReceipts(chatID: String, messageID: String) async throws -> [MessengerReadReceiptDTO] {
        try await backend.fetchReadReceipts(chatID: chatID, messageID: messageID)
    }

    func search(query: String, cursor: String?, limit: Int, includeArchived: Bool) async throws -> MessengerSearchPageDTO {
        try await backend.searchMessenger(query: query, cursor: cursor, limit: limit, includeArchived: includeArchived)
    }

    func uploadMedia(_ media: PersistedMessengerMedia) async throws -> MessengerMediaCompleteResponse {
        let register = try await backend.registerMessengerMedia(
            MessengerMediaRegisterRequest(
                filename: media.originalFilename,
                fileSize: media.fileSize,
                mimeType: media.mimeType,
                sha256: media.sha256
            )
        )
        guard let uploadURL = URL(string: register.uploadURL) else {
            throw MessengerSyncServiceError.invalidUploadURL
        }

        try await backend.uploadAnalysisVideo(
            uploadURL: uploadURL,
            headers: register.uploadHeaders,
            fileURL: media.localURL
        )

        return try await backend.completeMessengerMedia(
            mediaID: register.mediaID,
            request: MessengerMediaCompleteRequest(
                fileSize: media.fileSize,
                sha256: media.sha256,
                completedAt: Date()
            )
        )
    }

    func fetchMediaDownloadURL(mediaID: String) async throws -> MessengerMediaDownloadResponse {
        try await backend.fetchMessengerMediaDownloadURL(mediaID: mediaID)
    }

    func fetchRealtimeToken() async throws -> MessengerRealtimeTokenResponse {
        try await backend.fetchMessengerRealtimeToken()
    }
}

