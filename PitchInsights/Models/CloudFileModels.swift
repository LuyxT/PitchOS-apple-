import Foundation

enum CloudFileType: String, Codable, CaseIterable, Identifiable {
    case video
    case clip
    case tacticboard
    case trainingplan
    case image
    case document
    case export
    case analysisExport
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .video: return "Video"
        case .clip: return "Clip"
        case .tacticboard: return "Taktik"
        case .trainingplan: return "Training"
        case .image: return "Bild"
        case .document: return "Dokument"
        case .export: return "Export"
        case .analysisExport: return "Analyse-Export"
        case .other: return "Datei"
        }
    }

    var iconName: String {
        switch self {
        case .video: return "video"
        case .clip: return "film"
        case .tacticboard: return "sportscourt"
        case .trainingplan: return "list.bullet.rectangle"
        case .image: return "photo"
        case .document: return "doc.text"
        case .export: return "square.and.arrow.up"
        case .analysisExport: return "waveform.path.ecg"
        case .other: return "doc"
        }
    }
}

enum CloudModuleHint: String, Codable, CaseIterable, Identifiable {
    case analysis
    case tactics
    case training
    case messenger
    case administration
    case cash
    case generic

    var id: String { rawValue }
}

enum CloudFileVisibility: String, Codable, CaseIterable, Identifiable {
    case teamWide
    case restricted
    case explicitShareList

    var id: String { rawValue }
}

enum CloudUploadStatus: String, Codable, CaseIterable, Identifiable {
    case queued
    case uploading
    case ready
    case failed

    var id: String { rawValue }
}

enum CloudFileSortField: String, Codable, CaseIterable, Identifiable {
    case name
    case createdAt
    case updatedAt
    case sizeBytes

    var id: String { rawValue }
}

enum CloudSortDirection: String, Codable, CaseIterable, Identifiable {
    case ascending
    case descending

    var id: String { rawValue }
}

enum CloudStorageWarningLevel {
    case normal
    case warning
    case critical
}

enum CloudSystemFolder: String, CaseIterable, Identifiable {
    case root = "/"
    case videos = "Videos"
    case clips = "Clips"
    case analyses = "Analysen"
    case tactics = "Taktiken"
    case trainings = "Trainings"
    case images = "Bilder"
    case documents = "Dokumente"
    case exports = "Exporte"
    case trash = "Papierkorb"

    var id: String { rawValue }
}

struct CloudFolder: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var teamID: String
    var parentID: UUID?
    var parentBackendID: String?
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var isSystemFolder: Bool
    var isDeleted: Bool
}

struct CloudFile: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var teamID: String
    var ownerUserID: String
    var name: String
    var originalName: String
    var type: CloudFileType
    var mimeType: String
    var sizeBytes: Int64
    var createdAt: Date
    var updatedAt: Date
    var folderID: UUID?
    var folderBackendID: String?
    var tags: [String]
    var moduleHint: CloudModuleHint
    var visibility: CloudFileVisibility
    var sharedUserIDs: [String]
    var checksum: String?
    var uploadStatus: CloudUploadStatus
    var deletedAt: Date?
    var localCacheRelativePath: String?
    var linkedAnalysisSessionID: UUID?
    var linkedAnalysisClipID: UUID?
    var linkedTacticsScenarioID: UUID?
    var linkedTrainingPlanID: UUID?
}

struct TeamStorageUsage: Codable, Hashable {
    var teamID: String
    var quotaBytes: Int64
    var usedBytes: Int64
    var updatedAt: Date

    var remainingBytes: Int64 {
        max(0, quotaBytes - usedBytes)
    }

    var utilization: Double {
        guard quotaBytes > 0 else { return 0 }
        return min(1, max(0, Double(usedBytes) / Double(quotaBytes)))
    }

    var warningLevel: CloudStorageWarningLevel {
        let value = utilization
        if value >= 0.95 {
            return .critical
        }
        if value >= 0.8 {
            return .warning
        }
        return .normal
    }

    static let `default` = TeamStorageUsage(
        teamID: "team.default",
        quotaBytes: 5 * 1024 * 1024 * 1024,
        usedBytes: 0,
        updatedAt: Date()
    )
}

struct CloudFileFilterState: Equatable {
    var query: String = ""
    var type: CloudFileType?
    var fromDate: Date?
    var toDate: Date?
    var minSizeBytes: Int64?
    var maxSizeBytes: Int64?
    var folderID: UUID?
    var ownerUserID: String?
    var status: CloudFileStatus = .active
    var sortField: CloudFileSortField = .updatedAt
    var sortDirection: CloudSortDirection = .descending
}

enum CloudFileStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case trash

    var id: String { rawValue }
}

struct CloudUploadProgress: Identifiable, Equatable {
    let id: UUID
    var filename: String
    var totalBytes: Int64
    var uploadedBytes: Int64
    var state: CloudUploadStatus
    var message: String?

    var progressValue: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, max(0, Double(uploadedBytes) / Double(totalBytes)))
    }
}

struct CloudFilePage: Equatable {
    var items: [CloudFile]
    var nextCursor: String?
}

extension CloudFile {
    var isDeleted: Bool {
        deletedAt != nil
    }

    var normalizedTags: [String] {
        tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
