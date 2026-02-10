import Foundation
import SwiftUI
import Combine

@MainActor
final class FilesWorkspaceViewModel: ObservableObject {
    @Published var filter = CloudFileFilterState()
    @Published var selectedFileID: UUID?
    @Published var selectedFolderID: UUID?
    @Published var isBootstrapping = false
    @Published var isUploading = false
    @Published var statusMessage: String?
    @Published var showOnlyCurrentFolder = true

    func bootstrapIfNeeded(store: AppDataStore) async {
        if store.cloudFolders.isEmpty {
            await bootstrap(store: store)
            return
        }
        if selectedFolderID == nil {
            selectedFolderID = store.cloudActiveFolderID ?? store.cloudFolders.first(where: { $0.name == CloudSystemFolder.root.rawValue })?.id
        }
        filter.folderID = selectedFolderID
    }

    func bootstrap(store: AppDataStore) async {
        isBootstrapping = true
        defer { isBootstrapping = false }
        await store.bootstrapCloudFiles()
        selectedFolderID = store.cloudActiveFolderID ?? store.cloudFolders.first(where: { $0.name == CloudSystemFolder.root.rawValue })?.id
        filter.folderID = selectedFolderID
        await store.refreshCloudFiles(filter: filter)
    }

    func refresh(store: AppDataStore) async {
        if filter.status == .trash {
            await store.refreshCloudTrash(filter: filter, cursor: nil)
        } else {
            await store.refreshCloudFiles(filter: filter, cursor: nil)
        }
    }

    func loadMore(store: AppDataStore) async {
        guard let cursor = store.cloudFileNextCursor else { return }
        if filter.status == .trash {
            await store.refreshCloudTrash(filter: filter, cursor: cursor)
        } else {
            await store.refreshCloudFiles(filter: filter, cursor: cursor)
        }
    }

    func visibleFolders(in store: AppDataStore) -> [CloudFolder] {
        if filter.status == .trash {
            return store.cloudFolders.filter { !$0.isDeleted }
        }
        return store.cloudFolders.filter { !$0.isDeleted }.sorted { lhs, rhs in
            if lhs.parentID == nil && rhs.parentID != nil { return true }
            if lhs.parentID != nil && rhs.parentID == nil { return false }
            if lhs.isSystemFolder != rhs.isSystemFolder {
                return lhs.isSystemFolder
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func files(in store: AppDataStore) -> [CloudFile] {
        var activeFilter = filter
        activeFilter.folderID = showOnlyCurrentFolder ? selectedFolderID : nil
        return store.cloudFilesForUI(filter: activeFilter)
    }

    func selectFolder(_ folderID: UUID?, store: AppDataStore) {
        selectedFolderID = folderID
        store.cloudActiveFolderID = folderID
        if showOnlyCurrentFolder {
            filter.folderID = folderID
        }
    }

    func toggleTrash(_ enabled: Bool) {
        filter.status = enabled ? .trash : .active
        selectedFileID = nil
    }

    func createFolder(name: String, store: AppDataStore) async {
        do {
            let folder = try await store.createCloudFolder(name: name, parentID: selectedFolderID)
            selectedFolderID = folder.id
            filter.folderID = folder.id
            statusMessage = "Ordner erstellt"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func upload(urls: [URL], store: AppDataStore, typeHint: CloudFileType? = nil) async {
        guard !urls.isEmpty else { return }
        isUploading = true
        defer { isUploading = false }

        for url in urls {
            do {
                _ = try await store.uploadCloudFile(
                    from: url,
                    preferredType: typeHint,
                    moduleHint: .generic,
                    folderID: selectedFolderID
                )
                statusMessage = "Upload abgeschlossen"
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    func moveToTrashSelected(store: AppDataStore) async {
        guard let selectedFileID else { return }
        do {
            try await store.moveCloudFileToTrash(fileID: selectedFileID)
            self.selectedFileID = nil
            statusMessage = "In Papierkorb verschoben"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func restoreSelected(store: AppDataStore) async {
        guard let selectedFileID else { return }
        do {
            try await store.restoreCloudFile(fileID: selectedFileID, targetFolderID: store.resolveDefaultFolderID(for: .document))
            statusMessage = "Wiederhergestellt"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func deleteSelectedPermanently(store: AppDataStore) async {
        guard let selectedFileID else { return }
        do {
            try await store.deleteCloudFilePermanently(fileID: selectedFileID)
            self.selectedFileID = nil
            statusMessage = "Endgültig gelöscht"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func renameSelected(to name: String, store: AppDataStore) async {
        guard let selectedFileID else { return }
        do {
            try await store.updateCloudFile(fileID: selectedFileID, name: name, tags: nil, visibility: nil)
            statusMessage = "Umbenannt"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func openSelected(store: AppDataStore, appState: AppState) async {
        guard let selectedFileID else { return }
        await store.openCloudFile(fileID: selectedFileID, appState: appState)
    }
}
