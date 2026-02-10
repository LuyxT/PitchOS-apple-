import Foundation
import CryptoKit
import UniformTypeIdentifiers

struct PersistedMessengerMedia {
    var mediaID: UUID
    var originalFilename: String
    var localRelativePath: String
    var localURL: URL
    var fileSize: Int64
    var mimeType: String
    var sha256: String
    var kind: MessengerAttachmentKind
}

enum MessengerMediaStoreError: LocalizedError {
    case invalidSource
    case unsupportedType
    case appSupportUnavailable
    case fileCopyFailed
    case metadataUnavailable
    case hashFailed

    var errorDescription: String? {
        switch self {
        case .invalidSource:
            return "Ungültige Mediendatei."
        case .unsupportedType:
            return "Dateityp wird nicht unterstützt."
        case .appSupportUnavailable:
            return "App-Speicher nicht verfügbar."
        case .fileCopyFailed:
            return "Mediendatei konnte nicht gespeichert werden."
        case .metadataUnavailable:
            return "Dateimetadaten nicht verfügbar."
        case .hashFailed:
            return "Datei-Prüfsumme konnte nicht berechnet werden."
        }
    }
}

final class MessengerMediaStore {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func persistImportedMedia(from sourceURL: URL) throws -> PersistedMessengerMedia {
        guard sourceURL.isFileURL else {
            throw MessengerMediaStoreError.invalidSource
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

        let kind = try detectAttachmentKind(for: sourceURL)
        let mediaID = UUID()
        let dir = try mediaDirectoryURL()
        let ext = sourceURL.pathExtension
        let filename = ext.isEmpty ? mediaID.uuidString : "\(mediaID.uuidString).\(ext)"
        let destination = dir.appendingPathComponent(filename)

        do {
            if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: sourceURL, to: destination)
        } catch {
            throw MessengerMediaStoreError.fileCopyFailed
        }

        guard let attrs = try? fileManager.attributesOfItem(atPath: destination.path(percentEncoded: false)),
              let sizeNumber = attrs[.size] as? NSNumber else {
            throw MessengerMediaStoreError.metadataUnavailable
        }

        let sha = try calculateSHA256(for: destination)
        let mime = detectMimeType(for: destination)

        return PersistedMessengerMedia(
            mediaID: mediaID,
            originalFilename: sourceURL.lastPathComponent,
            localRelativePath: "MessengerMedia/\(filename)",
            localURL: destination,
            fileSize: sizeNumber.int64Value,
            mimeType: mime,
            sha256: sha,
            kind: kind
        )
    }

    func fileURL(for relativePath: String) -> URL? {
        guard let root = try? rootDirectoryURL() else { return nil }
        return root.appendingPathComponent(relativePath)
    }

    func removeMedia(relativePath: String) {
        guard let root = try? rootDirectoryURL() else { return }
        try? fileManager.removeItem(at: root.appendingPathComponent(relativePath))
    }

    private func detectAttachmentKind(for url: URL) throws -> MessengerAttachmentKind {
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            throw MessengerMediaStoreError.unsupportedType
        }
        if type.conforms(to: .image) {
            return .image
        }
        if type.conforms(to: .movie) || type.conforms(to: .video) {
            return .video
        }
        throw MessengerMediaStoreError.unsupportedType
    }

    private func mediaDirectoryURL() throws -> URL {
        let root = try rootDirectoryURL()
        let dir = root.appendingPathComponent("MessengerMedia", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path(percentEncoded: false)) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func rootDirectoryURL() throws -> URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw MessengerMediaStoreError.appSupportUnavailable
        }
        let root = appSupport.appendingPathComponent("PitchInsights", isDirectory: true)
        if !fileManager.fileExists(atPath: root.path(percentEncoded: false)) {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }

    private func calculateSHA256(for fileURL: URL) throws -> String {
        guard let stream = InputStream(url: fileURL) else {
            throw MessengerMediaStoreError.hashFailed
        }
        stream.open()
        defer { stream.close() }

        var hasher = SHA256()
        let chunkSize = 1024 * 1024
        var buffer = [UInt8](repeating: 0, count: chunkSize)

        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: chunkSize)
            if count < 0 {
                throw MessengerMediaStoreError.hashFailed
            }
            if count == 0 {
                break
            }
            hasher.update(data: Data(buffer.prefix(count)))
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func detectMimeType(for fileURL: URL) -> String {
        guard let type = UTType(filenameExtension: fileURL.pathExtension) else {
            return "application/octet-stream"
        }
        return type.preferredMIMEType ?? "application/octet-stream"
    }
}

