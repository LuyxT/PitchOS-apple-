import Foundation

enum AnalysisSyncServiceError: LocalizedError {
    case invalidUploadURL

    var errorDescription: String? {
        switch self {
        case .invalidUploadURL:
            return "Die Upload-URL ist ungültig."
        }
    }
}

final class AnalysisSyncService {
    private let backend: BackendRepository

    init(backend: BackendRepository) {
        self.backend = backend
    }

    func registerUploadAndCompleteVideo(_ persistedVideo: PersistedAnalysisVideo) async throws -> AnalysisVideoRegisterResponse {
        let registerRequest = AnalysisVideoRegisterRequest(
            filename: persistedVideo.originalFilename,
            fileSize: persistedVideo.fileSize,
            mimeType: persistedVideo.mimeType,
            sha256: persistedVideo.sha256,
            importedAt: Date()
        )

        let registerResponse = try await backend.registerAnalysisVideo(registerRequest)
        guard let uploadURL = URL(string: registerResponse.uploadURL) else {
            throw AnalysisSyncServiceError.invalidUploadURL
        }

        try await backend.uploadAnalysisVideo(
            uploadURL: uploadURL,
            headers: registerResponse.uploadHeaders,
            fileURL: persistedVideo.localURL
        )

        let completeRequest = AnalysisVideoCompleteRequest(
            fileSize: persistedVideo.fileSize,
            sha256: persistedVideo.sha256,
            completedAt: Date()
        )
        _ = try await backend.completeAnalysisVideo(videoID: registerResponse.videoID, request: completeRequest)
        return registerResponse
    }

    func createSession(_ request: CreateAnalysisSessionRequest) async throws -> AnalysisSessionDTO {
        try await backend.createAnalysisSession(request)
    }

    func fetchSession(id: String) async throws -> AnalysisSessionEnvelopeDTO {
        try await backend.fetchAnalysisSession(id: id)
    }

    func addMarker(_ request: CreateAnalysisMarkerRequest) async throws -> AnalysisMarkerDTO {
        try await backend.createAnalysisMarker(request)
    }

    func updateMarker(id: String, request: UpdateAnalysisMarkerRequest) async throws -> AnalysisMarkerDTO {
        try await backend.updateAnalysisMarker(id: id, request: request)
    }

    func deleteMarker(id: String) async throws {
        _ = try await backend.deleteAnalysisMarker(id: id)
    }

    func createClip(_ request: CreateAnalysisClipRequest) async throws -> AnalysisClipDTO {
        try await backend.createAnalysisClip(request)
    }

    func updateClip(id: String, request: UpdateAnalysisClipRequest) async throws -> AnalysisClipDTO {
        try await backend.updateAnalysisClip(id: id, request: request)
    }

    func deleteClip(id: String) async throws {
        _ = try await backend.deleteAnalysisClip(id: id)
    }

    func saveDrawings(sessionID: String, drawings: [AnalysisDrawing]) async throws {
        let drawingDTOs = drawings.map {
            AnalysisDrawingDTO(
                id: $0.backendDrawingID,
                localID: $0.id,
                tool: $0.tool.rawValue,
                points: $0.points.map { .init(x: $0.x, y: $0.y) },
                colorHex: $0.colorHex,
                isTemporary: $0.isTemporary,
                timeSeconds: $0.timeSeconds,
                createdAt: $0.createdAt
            )
        }
        let request = SaveAnalysisDrawingsRequest(drawings: drawingDTOs)
        _ = try await backend.saveAnalysisDrawings(sessionID: sessionID, request: request)
    }

    func shareClip(_ request: AnalysisShareRequest, backendClipID: String) async throws -> ShareAnalysisClipResponse {
        let dto = ShareAnalysisClipRequest(
            playerIDs: request.playerIDs,
            threadID: request.threadID,
            message: request.message
        )
        return try await backend.shareAnalysisClip(clipID: backendClipID, request: dto)
    }
}
