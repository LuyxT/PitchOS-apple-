import Foundation

enum AnalysisSyncState: String, Codable, CaseIterable {
    case pending
    case synced
    case syncFailed
}

struct AnalysisVideoAsset: Identifiable, Codable, Hashable {
    let id: UUID
    var backendVideoID: String?
    var cloudFileID: UUID?
    var originalFilename: String
    var localRelativePath: String
    var fileSize: Int64
    var mimeType: String
    var sha256: String
    var createdAt: Date
    var uploadedAt: Date?
    var syncState: AnalysisSyncState

    init(
        id: UUID = UUID(),
        backendVideoID: String? = nil,
        cloudFileID: UUID? = nil,
        originalFilename: String,
        localRelativePath: String,
        fileSize: Int64,
        mimeType: String,
        sha256: String,
        createdAt: Date = Date(),
        uploadedAt: Date? = nil,
        syncState: AnalysisSyncState = .pending
    ) {
        self.id = id
        self.backendVideoID = backendVideoID
        self.cloudFileID = cloudFileID
        self.originalFilename = originalFilename
        self.localRelativePath = localRelativePath
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.sha256 = sha256
        self.createdAt = createdAt
        self.uploadedAt = uploadedAt
        self.syncState = syncState
    }
}

struct AnalysisSession: Identifiable, Codable, Hashable {
    let id: UUID
    var backendSessionID: String?
    var videoAssetID: UUID
    var title: String
    var matchID: UUID?
    var teamID: String?
    var createdAt: Date
    var updatedAt: Date
    var syncState: AnalysisSyncState

    init(
        id: UUID = UUID(),
        backendSessionID: String? = nil,
        videoAssetID: UUID,
        title: String,
        matchID: UUID? = nil,
        teamID: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncState: AnalysisSyncState = .pending
    ) {
        self.id = id
        self.backendSessionID = backendSessionID
        self.videoAssetID = videoAssetID
        self.title = title
        self.matchID = matchID
        self.teamID = teamID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncState = syncState
    }
}

struct AnalysisMarkerCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String
    var isSystem: Bool

    init(id: UUID = UUID(), name: String, colorHex: String, isSystem: Bool = false) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isSystem = isSystem
    }
}

struct AnalysisMarker: Identifiable, Codable, Hashable {
    let id: UUID
    var backendMarkerID: String?
    var sessionID: UUID
    var videoAssetID: UUID
    var timeSeconds: Double
    var categoryID: UUID?
    var comment: String
    var playerID: UUID?
    var createdAt: Date
    var updatedAt: Date
    var syncState: AnalysisSyncState

    init(
        id: UUID = UUID(),
        backendMarkerID: String? = nil,
        sessionID: UUID,
        videoAssetID: UUID,
        timeSeconds: Double,
        categoryID: UUID? = nil,
        comment: String = "",
        playerID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncState: AnalysisSyncState = .pending
    ) {
        self.id = id
        self.backendMarkerID = backendMarkerID
        self.sessionID = sessionID
        self.videoAssetID = videoAssetID
        self.timeSeconds = max(0, timeSeconds)
        self.categoryID = categoryID
        self.comment = comment
        self.playerID = playerID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncState = syncState
    }
}

struct AnalysisClip: Identifiable, Codable, Hashable {
    let id: UUID
    var backendClipID: String?
    var sessionID: UUID
    var videoAssetID: UUID
    var name: String
    var startSeconds: Double
    var endSeconds: Double
    var playerIDs: [UUID]
    var note: String
    var createdAt: Date
    var updatedAt: Date
    var syncState: AnalysisSyncState

    init(
        id: UUID = UUID(),
        backendClipID: String? = nil,
        sessionID: UUID,
        videoAssetID: UUID,
        name: String,
        startSeconds: Double,
        endSeconds: Double,
        playerIDs: [UUID] = [],
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncState: AnalysisSyncState = .pending
    ) {
        self.id = id
        self.backendClipID = backendClipID
        self.sessionID = sessionID
        self.videoAssetID = videoAssetID
        self.name = name
        self.startSeconds = max(0, startSeconds)
        self.endSeconds = max(endSeconds, startSeconds)
        self.playerIDs = playerIDs
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncState = syncState
    }

    var duration: Double {
        max(0, endSeconds - startSeconds)
    }
}

enum AnalysisDrawingTool: String, Codable, CaseIterable, Identifiable {
    case line
    case arrow
    case circle
    case rectangle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .line:
            return "Linie"
        case .arrow:
            return "Pfeil"
        case .circle:
            return "Kreis"
        case .rectangle:
            return "Rechteck"
        }
    }
}

struct AnalysisPoint: Codable, Hashable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = min(1, max(0, x))
        self.y = min(1, max(0, y))
    }
}

struct AnalysisDrawing: Identifiable, Codable, Hashable {
    let id: UUID
    var backendDrawingID: String?
    var sessionID: UUID
    var timeSeconds: Double
    var tool: AnalysisDrawingTool
    var points: [AnalysisPoint]
    var colorHex: String
    var isTemporary: Bool
    var createdAt: Date
    var syncState: AnalysisSyncState

    init(
        id: UUID = UUID(),
        backendDrawingID: String? = nil,
        sessionID: UUID,
        timeSeconds: Double,
        tool: AnalysisDrawingTool,
        points: [AnalysisPoint],
        colorHex: String = "#10B981",
        isTemporary: Bool,
        createdAt: Date = Date(),
        syncState: AnalysisSyncState = .pending
    ) {
        self.id = id
        self.backendDrawingID = backendDrawingID
        self.sessionID = sessionID
        self.timeSeconds = max(0, timeSeconds)
        self.tool = tool
        self.points = points
        self.colorHex = colorHex
        self.isTemporary = isTemporary
        self.createdAt = createdAt
        self.syncState = syncState
    }
}

struct AnalysisFilterState: Hashable {
    var categoryIDs: Set<UUID> = []
    var playerIDs: Set<UUID> = []
}

struct AnalysisShareRequest: Hashable {
    var clipID: UUID
    var playerIDs: [UUID]
    var threadID: UUID?
    var message: String
}

struct AnalysisSessionBundle {
    var session: AnalysisSession
    var markers: [AnalysisMarker]
    var clips: [AnalysisClip]
    var drawings: [AnalysisDrawing]
}

extension AnalysisMarkerCategory {
    static let `default`: [AnalysisMarkerCategory] = [
        AnalysisMarkerCategory(name: "Tor", colorHex: "#10B981", isSystem: true),
        AnalysisMarkerCategory(name: "Pressing", colorHex: "#3B82F6", isSystem: true),
        AnalysisMarkerCategory(name: "Aufbau", colorHex: "#F59E0B", isSystem: true)
    ]
}
