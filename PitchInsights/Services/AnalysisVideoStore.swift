import Foundation
import CryptoKit
import UniformTypeIdentifiers

struct PersistedAnalysisVideo {
    var assetID: UUID
    var originalFilename: String
    var localRelativePath: String
    var localURL: URL
    var fileSize: Int64
    var mimeType: String
    var sha256: String
}

enum AnalysisVideoStoreError: LocalizedError {
    case invalidSource
    case appSupportUnavailable
    case fileCopyFailed
    case fileMetadataUnavailable
    case hashFailed

    var errorDescription: String? {
        switch self {
        case .invalidSource:
            return "Videoquelle ist ungültig."
        case .appSupportUnavailable:
            return "App-Speicher ist nicht verfügbar."
        case .fileCopyFailed:
            return "Video konnte nicht gespeichert werden."
        case .fileMetadataUnavailable:
            return "Video-Metadaten konnten nicht gelesen werden."
        case .hashFailed:
            return "Video-Prüfsumme konnte nicht berechnet werden."
        }
    }
}

final class AnalysisVideoStore {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func persistImportedVideo(from sourceURL: URL) throws -> PersistedAnalysisVideo {
        guard sourceURL.isFileURL else {
            throw AnalysisVideoStoreError.invalidSource
        }

        var didAccessScopedResource = false
        if sourceURL.startAccessingSecurityScopedResource() {
            didAccessScopedResource = true
        }
        defer {
            if didAccessScopedResource {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let assetID = UUID()
        let directory = try videoDirectoryURL()
        let originalFilename = sourceURL.lastPathComponent
        let fileExtension = sourceURL.pathExtension
        let targetFilename = fileExtension.isEmpty
            ? assetID.uuidString
            : "\(assetID.uuidString).\(fileExtension)"

        let targetURL = directory.appendingPathComponent(targetFilename, conformingTo: .movie)

        do {
            if fileManager.fileExists(atPath: targetURL.path(percentEncoded: false)) {
                try fileManager.removeItem(at: targetURL)
            }
            try fileManager.copyItem(at: sourceURL, to: targetURL)
        } catch {
            throw AnalysisVideoStoreError.fileCopyFailed
        }

        guard let attributes = try? fileManager.attributesOfItem(atPath: targetURL.path(percentEncoded: false)),
              let fileSizeNumber = attributes[.size] as? NSNumber else {
            throw AnalysisVideoStoreError.fileMetadataUnavailable
        }

        let sha256 = try calculateSHA256(for: targetURL)
        let mimeType = detectMimeType(for: targetURL)
        let relativePath = "AnalysisVideos/\(targetFilename)"

        return PersistedAnalysisVideo(
            assetID: assetID,
            originalFilename: originalFilename,
            localRelativePath: relativePath,
            localURL: targetURL,
            fileSize: fileSizeNumber.int64Value,
            mimeType: mimeType,
            sha256: sha256
        )
    }

    func removeVideo(relativePath: String) {
        guard let root = try? rootDirectoryURL() else { return }
        let fileURL = root.appendingPathComponent(relativePath)
        try? fileManager.removeItem(at: fileURL)
    }

    func fileURL(for relativePath: String) -> URL? {
        guard let root = try? rootDirectoryURL() else { return nil }
        return root.appendingPathComponent(relativePath)
    }

    private func videoDirectoryURL() throws -> URL {
        let root = try rootDirectoryURL()
        let directory = root.appendingPathComponent("AnalysisVideos", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path(percentEncoded: false)) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func rootDirectoryURL() throws -> URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw AnalysisVideoStoreError.appSupportUnavailable
        }
        let root = appSupport.appendingPathComponent("PitchInsights", isDirectory: true)
        if !fileManager.fileExists(atPath: root.path(percentEncoded: false)) {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }

    private func calculateSHA256(for fileURL: URL) throws -> String {
        guard let stream = InputStream(url: fileURL) else {
            throw AnalysisVideoStoreError.hashFailed
        }

        stream.open()
        defer { stream.close() }

        var hasher = SHA256()
        let bufferSize = 1024 * 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read < 0 {
                throw AnalysisVideoStoreError.hashFailed
            }
            if read == 0 {
                break
            }
            hasher.update(data: Data(buffer.prefix(read)))
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func detectMimeType(for fileURL: URL) -> String {
        guard let type = UTType(filenameExtension: fileURL.pathExtension) else {
            return "application/octet-stream"
        }
        return type.preferredMIMEType ?? "application/octet-stream"
    }
}
