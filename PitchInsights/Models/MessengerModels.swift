import Foundation

enum MessengerConnectionState: Equatable {
    case placeholder
    case disconnected
    case connecting
    case connected
    case failed(String)
}

enum MessengerChatType: String, Codable, CaseIterable, Identifiable {
    case direct
    case group

    var id: String { rawValue }
}

enum MessengerMembershipRole: String, Codable, CaseIterable, Identifiable {
    case trainer
    case player

    var id: String { rawValue }
}

enum MessengerChatPermission: String, Codable, CaseIterable, Identifiable {
    case trainerOnly
    case allMembers
    case custom

    var id: String { rawValue }
}

enum MessengerMessageType: String, Codable, CaseIterable, Identifiable {
    case text
    case image
    case video
    case analysisClipReference

    var id: String { rawValue }
}

enum MessengerMessageStatus: String, Codable, CaseIterable, Identifiable {
    case queued
    case uploading
    case sent
    case delivered
    case read
    case failed

    var id: String { rawValue }
}

enum MessengerAttachmentKind: String, Codable, CaseIterable, Identifiable {
    case image
    case video

    var id: String { rawValue }
}

enum MessengerSearchResultType: String, Codable, CaseIterable, Identifiable {
    case chat
    case message
    case analysisClip
    case analysisMarker

    var id: String { rawValue }
}

struct MessengerCurrentUser: Equatable, Hashable, Codable {
    var userID: String
    var displayName: String
    var role: MessengerMembershipRole
    var clubID: String
    var teamIDs: [String]
}

struct MessengerParticipant: Identifiable, Equatable, Hashable, Codable {
    let id: UUID
    var backendUserID: String
    var displayName: String
    var role: MessengerMembershipRole
    var playerID: UUID?
    var mutedUntil: Date?
    var canWrite: Bool
    var joinedAt: Date

    init(
        id: UUID = UUID(),
        backendUserID: String,
        displayName: String,
        role: MessengerMembershipRole,
        playerID: UUID? = nil,
        mutedUntil: Date? = nil,
        canWrite: Bool = true,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.backendUserID = backendUserID
        self.displayName = displayName
        self.role = role
        self.playerID = playerID
        self.mutedUntil = mutedUntil
        self.canWrite = canWrite
        self.joinedAt = joinedAt
    }
}

struct MessengerAttachment: Identifiable, Equatable, Hashable, Codable {
    let id: UUID
    var backendMediaID: String?
    var kind: MessengerAttachmentKind
    var filename: String
    var mimeType: String
    var fileSize: Int64
    var sha256: String?
    var localRelativePath: String?
    var uploadState: MessengerMessageStatus

    init(
        id: UUID = UUID(),
        backendMediaID: String? = nil,
        kind: MessengerAttachmentKind,
        filename: String,
        mimeType: String,
        fileSize: Int64,
        sha256: String? = nil,
        localRelativePath: String? = nil,
        uploadState: MessengerMessageStatus = .queued
    ) {
        self.id = id
        self.backendMediaID = backendMediaID
        self.kind = kind
        self.filename = filename
        self.mimeType = mimeType
        self.fileSize = fileSize
        self.sha256 = sha256
        self.localRelativePath = localRelativePath
        self.uploadState = uploadState
    }
}

struct MessengerClipReference: Identifiable, Equatable, Hashable, Codable {
    let id: UUID
    var backendClipID: String
    var backendAnalysisSessionID: String
    var backendVideoAssetID: String
    var clipID: UUID?
    var analysisSessionID: UUID?
    var videoAssetID: UUID?
    var clipName: String
    var timeStart: Double
    var timeEnd: Double
    var matchID: UUID?

    init(
        id: UUID = UUID(),
        backendClipID: String,
        backendAnalysisSessionID: String,
        backendVideoAssetID: String,
        clipID: UUID? = nil,
        analysisSessionID: UUID? = nil,
        videoAssetID: UUID? = nil,
        clipName: String,
        timeStart: Double,
        timeEnd: Double,
        matchID: UUID? = nil
    ) {
        self.id = id
        self.backendClipID = backendClipID
        self.backendAnalysisSessionID = backendAnalysisSessionID
        self.backendVideoAssetID = backendVideoAssetID
        self.clipID = clipID
        self.analysisSessionID = analysisSessionID
        self.videoAssetID = videoAssetID
        self.clipName = clipName
        self.timeStart = timeStart
        self.timeEnd = timeEnd
        self.matchID = matchID
    }
}

struct MessengerReadReceipt: Identifiable, Equatable, Hashable, Codable {
    let id: UUID
    var userID: String
    var userName: String
    var readAt: Date

    init(id: UUID = UUID(), userID: String, userName: String, readAt: Date) {
        self.id = id
        self.userID = userID
        self.userName = userName
        self.readAt = readAt
    }
}

struct MessengerMessage: Identifiable, Equatable, Hashable, Codable {
    var id: UUID
    var backendMessageID: String?
    var chatID: UUID
    var senderUserID: String
    var senderName: String
    var type: MessengerMessageType
    var text: String
    var contextLabel: String?
    var attachment: MessengerAttachment?
    var clipReference: MessengerClipReference?
    var createdAt: Date
    var updatedAt: Date
    var status: MessengerMessageStatus
    var readBy: [MessengerReadReceipt]
    var isMine: Bool

    init(
        id: UUID = UUID(),
        backendMessageID: String? = nil,
        chatID: UUID,
        senderUserID: String,
        senderName: String,
        type: MessengerMessageType,
        text: String = "",
        contextLabel: String? = nil,
        attachment: MessengerAttachment? = nil,
        clipReference: MessengerClipReference? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        status: MessengerMessageStatus = .queued,
        readBy: [MessengerReadReceipt] = [],
        isMine: Bool
    ) {
        self.id = id
        self.backendMessageID = backendMessageID
        self.chatID = chatID
        self.senderUserID = senderUserID
        self.senderName = senderName
        self.type = type
        self.text = text
        self.contextLabel = contextLabel
        self.attachment = attachment
        self.clipReference = clipReference
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.readBy = readBy
        self.isMine = isMine
    }
}

struct MessengerChat: Identifiable, Equatable, Hashable, Codable {
    let id: UUID
    var backendChatID: String
    var title: String
    var type: MessengerChatType
    var participants: [MessengerParticipant]
    var lastMessagePreview: String
    var lastMessageAt: Date?
    var unreadCount: Int
    var pinned: Bool
    var muted: Bool
    var archived: Bool
    var writePermission: MessengerChatPermission
    var temporaryUntil: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        backendChatID: String,
        title: String,
        type: MessengerChatType,
        participants: [MessengerParticipant] = [],
        lastMessagePreview: String = "",
        lastMessageAt: Date? = nil,
        unreadCount: Int = 0,
        pinned: Bool = false,
        muted: Bool = false,
        archived: Bool = false,
        writePermission: MessengerChatPermission = .allMembers,
        temporaryUntil: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.backendChatID = backendChatID
        self.title = title
        self.type = type
        self.participants = participants
        self.lastMessagePreview = lastMessagePreview
        self.lastMessageAt = lastMessageAt
        self.unreadCount = unreadCount
        self.pinned = pinned
        self.muted = muted
        self.archived = archived
        self.writePermission = writePermission
        self.temporaryUntil = temporaryUntil
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct MessengerPagedResponse<T: Hashable & Codable>: Hashable, Codable {
    var items: [T]
    var nextCursor: String?
}

struct MessengerSearchResult: Identifiable, Equatable, Hashable, Codable {
    let id: UUID
    var type: MessengerSearchResultType
    var chatID: UUID?
    var messageID: UUID?
    var title: String
    var subtitle: String
    var occurredAt: Date?
}

enum MessengerOutboxPayloadKind: String, Codable {
    case text
    case media
    case clipReference
}

struct MessengerOutboxPayload: Equatable, Hashable, Codable {
    var kind: MessengerOutboxPayloadKind
    var text: String?
    var contextLabel: String?
    var attachment: MessengerAttachment?
    var clipReference: MessengerClipReference?
}

struct MessengerOutboxItem: Identifiable, Equatable, Hashable, Codable {
    let id: UUID
    var localMessageID: UUID
    var chatID: UUID
    var createdAt: Date
    var payload: MessengerOutboxPayload
    var attemptCount: Int
    var nextRetryAt: Date?
    var lastError: String?
}
