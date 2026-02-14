import Foundation

enum CloudFileSyncError: LocalizedError {
    case invalidUploadURL
    case missingUploadIdentifier
    case invalidChunkSize

    var errorDescription: String? {
        switch self {
        case .invalidUploadURL:
            return "Upload-URL ist ungültig."
        case .missingUploadIdentifier:
            return "Upload-Kennung fehlt."
        case .invalidChunkSize:
            return "Ungültige Upload-Chunkgröße."
        }
    }
}

final class CloudFileSyncService {
    private let backend: BackendRepository

    init(backend: BackendRepository) {
        self.backend = backend
    }

    func fetchBootstrap(teamID: String) async throws -> CloudFilesBootstrapDTO {
        try await backend.fetchCloudFilesBootstrap(teamID: teamID)
    }

    func fetchFiles(_ request: CloudFilesQueryRequest) async throws -> CloudFilesPageDTO {
        try await backend.fetchCloudFiles(request)
    }

    func fetchTrash(_ request: CloudFilesQueryRequest) async throws -> CloudFilesPageDTO {
        try await backend.fetchCloudTrash(request)
    }

    func createFolder(_ request: CreateCloudFolderRequest) async throws -> CloudFolderDTO {
        try await backend.createCloudFolder(request)
    }

    func updateFolder(folderID: String, request: UpdateCloudFolderRequest) async throws -> CloudFolderDTO {
        try await backend.updateCloudFolder(folderID: folderID, request: request)
    }

    func registerAndUploadFile(
        importedFile: PersistedCloudImport,
        request: RegisterCloudFileUploadRequest,
        onProgress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws -> CloudFileDTO {
        let register = try await backend.registerCloudFileUpload(request)

        let resolvedURLString = register.uploadURL.hasPrefix("http")
            ? register.uploadURL
            : AppConfiguration.API_BASE_URL + register.uploadURL
        guard let uploadURL = URL(string: resolvedURLString) else {
            throw CloudFileSyncError.invalidUploadURL
        }
        guard !register.uploadID.isEmpty else {
            throw CloudFileSyncError.missingUploadIdentifier
        }

        let chunkSize = max(1_048_576, register.chunkSizeBytes)
        let totalSize = importedFile.fileSize
        guard chunkSize > 0 else {
            throw CloudFileSyncError.invalidChunkSize
        }

        let fileHandle = try FileHandle(forReadingFrom: importedFile.localURL)
        defer {
            try? fileHandle.close()
        }

        var uploadedBytes: Int64 = 0
        var partNumber = 1
        var chunkDigests: [CloudUploadChunkDigestRequest] = []

        while uploadedBytes < totalSize {
            let readLength = Int(min(Int64(chunkSize), totalSize - uploadedBytes))
            let chunkData = fileHandle.readData(ofLength: readLength)
            if chunkData.isEmpty {
                break
            }

            let start = uploadedBytes
            uploadedBytes += Int64(chunkData.count)
            let end = max(start, uploadedBytes - 1)
            let contentRange = "bytes \(start)-\(end)/\(totalSize)"

            let etag = try await backend.uploadCloudFileChunk(
                uploadURL: uploadURL,
                uploadID: register.uploadID,
                partNumber: partNumber,
                totalParts: register.totalParts,
                headers: register.uploadHeaders,
                contentRange: contentRange,
                data: chunkData
            )
            chunkDigests.append(
                CloudUploadChunkDigestRequest(
                    partNumber: partNumber,
                    etag: etag,
                    sizeBytes: Int64(chunkData.count)
                )
            )
            onProgress(uploadedBytes, totalSize)
            partNumber += 1
        }

        let complete = CompleteCloudFileUploadRequest(
            uploadID: register.uploadID,
            fileSize: importedFile.fileSize,
            sha256: importedFile.sha256,
            chunks: chunkDigests
        )
        return try await backend.completeCloudFileUpload(fileID: register.fileID, request: complete)
    }

    func updateFile(fileID: String, request: UpdateCloudFileRequest) async throws -> CloudFileDTO {
        try await backend.updateCloudFile(fileID: fileID, request: request)
    }

    func moveFile(fileID: String, request: MoveCloudFileRequest) async throws -> CloudFileDTO {
        try await backend.moveCloudFile(fileID: fileID, request: request)
    }

    func trashFile(fileID: String, request: TrashCloudFileRequest) async throws -> CloudFileDTO {
        try await backend.trashCloudFile(fileID: fileID, request: request)
    }

    func restoreFile(fileID: String, request: RestoreCloudFileRequest) async throws -> CloudFileDTO {
        try await backend.restoreCloudFile(fileID: fileID, request: request)
    }

    func deleteFilePermanently(fileID: String) async throws {
        _ = try await backend.deleteCloudFilePermanently(fileID: fileID)
    }

    func listLargestFiles(teamID: String, limit: Int) async throws -> [CloudFileDTO] {
        try await backend.fetchLargestCloudFiles(teamID: teamID, limit: limit)
    }

    func listOldFiles(teamID: String, olderThanDays: Int, limit: Int) async throws -> [CloudFileDTO] {
        try await backend.fetchOldCloudFiles(teamID: teamID, olderThanDays: olderThanDays, limit: limit)
    }
}
