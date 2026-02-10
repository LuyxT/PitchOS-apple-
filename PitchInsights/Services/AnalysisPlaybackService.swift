import Foundation

enum AnalysisPlaybackServiceError: LocalizedError {
    case missingVideoID
    case signedURLInvalid

    var errorDescription: String? {
        switch self {
        case .missingVideoID:
            return "Für dieses Video ist keine Backend-Referenz vorhanden."
        case .signedURLInvalid:
            return "Die Playback-URL vom Backend ist ungültig."
        }
    }
}

final class AnalysisPlaybackService {
    init() {}

    func resolvedPlaybackURL(for asset: AnalysisVideoAsset, backend: BackendRepository) async throws -> URL {
        guard let videoID = asset.backendVideoID else {
            throw AnalysisPlaybackServiceError.missingVideoID
        }

        let response = try await backend.fetchPlaybackURL(videoID: videoID)
        guard let signedURL = URL(string: response.signedPlaybackURL) else {
            throw AnalysisPlaybackServiceError.signedURLInvalid
        }

        return signedURL
    }
}
