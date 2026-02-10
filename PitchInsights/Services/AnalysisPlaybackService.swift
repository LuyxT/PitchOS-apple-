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
    private let videoStore: AnalysisVideoStore

    init(videoStore: AnalysisVideoStore) {
        self.videoStore = videoStore
    }

    func resolvedPlaybackURL(for asset: AnalysisVideoAsset, backend: BackendRepository) async throws -> URL {
        if !asset.localRelativePath.isEmpty,
           let localURL = videoStore.fileURL(for: asset.localRelativePath),
           FileManager.default.fileExists(atPath: localURL.path(percentEncoded: false)) {
            return localURL
        }

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
