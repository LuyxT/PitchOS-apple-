import Foundation
import CryptoKit
import UniformTypeIdentifiers

struct PersistedCloudImport {
    var importID: UUID
    var filename: String
    var originalFilename: String
    var localRelativePath: String
    var localURL: URL
    var fileSize: Int64
    var mimeType: String
    var sha256: String
    var inferredType: CloudFileType
}

enum CloudFileStoreError: LocalizedError {
    case invalidSource
    case appSupportUnavailable
    case copyFailed
    case metadataUnavailable
    case hashFailed

    var errorDescription: String? {
        switch self {
        case .invalidSource:
            return "Ungültige Datei."
        case .appSupportUnavailable:
            return "App-Speicher nicht verfügbar."
        case .copyFailed:
            return "Datei konnte nicht gespeichert werden."
        case .metadataUnavailable:
            return "Datei-Metadaten konnten nicht gelesen werden."
        case .hashFailed:
            return "Datei-Prüfsumme konnte nicht berechnet werden."
        }
    }
}

final class CloudFileStore {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func persistImportedFile(from sourceURL: URL) throws -> PersistedCloudImport {
        guard sourceURL.isFileURL else {
            throw CloudFileStoreError.invalidSource
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

        let importID = UUID()
        let ext = sourceURL.pathExtension
        let filename = ext.isEmpty ? importID.uuidString : "\(importID.uuidString).\(ext)"
        let targetURL = try stagingDirectoryURL().appendingPathComponent(filename)

        do {
            if fileManager.fileExists(atPath: targetURL.path(percentEncoded: false)) {
                try fileManager.removeItem(at: targetURL)
            }
            try fileManager.copyItem(at: sourceURL, to: targetURL)
        } catch {
            throw CloudFileStoreError.copyFailed
        }

        guard let attributes = try? fileManager.attributesOfItem(atPath: targetURL.path(percentEncoded: false)),
              let sizeNumber = attributes[.size] as? NSNumber else {
            throw CloudFileStoreError.metadataUnavailable
        }

        let mimeType = detectMimeType(for: targetURL)
        let sha256 = try calculateSHA256(for: targetURL)

        return PersistedCloudImport(
            importID: importID,
            filename: filename,
            originalFilename: sourceURL.lastPathComponent,
            localRelativePath: "CloudStaging/\(filename)",
            localURL: targetURL,
            fileSize: sizeNumber.int64Value,
            mimeType: mimeType,
            sha256: sha256,
            inferredType: inferFileType(for: targetURL, mimeType: mimeType)
        )
    }

    func fileURL(for relativePath: String) -> URL? {
        guard let root = try? rootDirectoryURL() else { return nil }
        return root.appendingPathComponent(relativePath)
    }

    func removeFile(relativePath: String) {
        guard let root = try? rootDirectoryURL() else { return }
        try? fileManager.removeItem(at: root.appendingPathComponent(relativePath))
    }

    func detectMimeType(for fileURL: URL) -> String {
        guard let type = UTType(filenameExtension: fileURL.pathExtension) else {
            return "application/octet-stream"
        }
        return type.preferredMIMEType ?? "application/octet-stream"
    }

    func inferFileType(for fileURL: URL, mimeType: String? = nil) -> CloudFileType {
        let lowerMime = (mimeType ?? detectMimeType(for: fileURL)).lowercased()
        if lowerMime.hasPrefix("video/") {
            return .video
        }
        if lowerMime.hasPrefix("image/") {
            return .image
        }
        if lowerMime.contains("pdf") || lowerMime.hasPrefix("text/") || lowerMime.contains("word") {
            return .document
        }
        return .other
    }

    private func stagingDirectoryURL() throws -> URL {
        let root = try rootDirectoryURL()
        let directory = root.appendingPathComponent("CloudStaging", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path(percentEncoded: false)) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func rootDirectoryURL() throws -> URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CloudFileStoreError.appSupportUnavailable
        }
        let root = appSupport.appendingPathComponent("PitchInsights", isDirectory: true)
        if !fileManager.fileExists(atPath: root.path(percentEncoded: false)) {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }

    private func calculateSHA256(for fileURL: URL) throws -> String {
        guard let stream = InputStream(url: fileURL) else {
            throw CloudFileStoreError.hashFailed
        }
        stream.open()
        defer { stream.close() }

        var hasher = SHA256()
        let chunkSize = 1024 * 1024
        var buffer = [UInt8](repeating: 0, count: chunkSize)

        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: chunkSize)
            if count < 0 {
                throw CloudFileStoreError.hashFailed
            }
            if count == 0 {
                break
            }
            hasher.update(data: Data(buffer.prefix(count)))
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
