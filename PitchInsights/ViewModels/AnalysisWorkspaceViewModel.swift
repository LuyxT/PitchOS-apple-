import Foundation
import SwiftUI
import Combine

@MainActor
final class AnalysisWorkspaceViewModel: ObservableObject {
    @Published var selectedSessionID: UUID?
    @Published var filterState = AnalysisFilterState()
    @Published var selectedMarkerID: UUID?
    @Published var selectedClipID: UUID?
    @Published var clipStartTime: Double?
    @Published var isPresentationMode = false
    @Published var isCompareMode = false
    @Published var compareClipLeftID: UUID?
    @Published var compareClipRightID: UUID?
    @Published var isImportRunning = false
    @Published var importErrorMessage: String?
    @Published var statusMessage: String?

    func bootstrap(with store: AppDataStore) {
        if selectedSessionID == nil {
            selectedSessionID = store.activeAnalysisSessionID ?? store.analysisSessions.first?.id
        }
        store.activeAnalysisSessionID = selectedSessionID
    }

    func selectSession(_ sessionID: UUID, store: AppDataStore) {
        selectedSessionID = sessionID
        store.activeAnalysisSessionID = sessionID
    }

    func activeSession(in store: AppDataStore) -> AnalysisSession? {
        guard let selectedSessionID else { return nil }
        return store.analysisSessions.first(where: { $0.id == selectedSessionID })
    }

    func activeBundle(in store: AppDataStore) -> AnalysisSessionBundle? {
        guard let selectedSessionID else { return nil }
        return store.sessionBundle(for: selectedSessionID)
    }

    func filteredMarkers(in store: AppDataStore) -> [AnalysisMarker] {
        guard let selectedSessionID else { return [] }
        return store.analysisMarkers
            .filter { marker in
                guard marker.sessionID == selectedSessionID else { return false }
                if !filterState.categoryIDs.isEmpty,
                   let categoryID = marker.categoryID,
                   !filterState.categoryIDs.contains(categoryID) {
                    return false
                }
                if !filterState.playerIDs.isEmpty {
                    guard let playerID = marker.playerID else { return false }
                    if !filterState.playerIDs.contains(playerID) {
                        return false
                    }
                }
                return true
            }
            .sorted { $0.timeSeconds < $1.timeSeconds }
    }

    func clips(in store: AppDataStore) -> [AnalysisClip] {
        guard let selectedSessionID else { return [] }
        return store.analysisClips
            .filter { $0.sessionID == selectedSessionID }
            .sorted { $0.startSeconds < $1.startSeconds }
    }

    func drawings(in store: AppDataStore) -> [AnalysisDrawing] {
        guard let selectedSessionID else { return [] }
        return store.analysisDrawings
            .filter { $0.sessionID == selectedSessionID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func createAnalysis(from sourceURL: URL, title: String, store: AppDataStore) async {
        importErrorMessage = nil
        isImportRunning = true
        defer { isImportRunning = false }

        do {
            let session = try await store.createAnalysisFromImportedVideo(sourceURL: sourceURL, title: title)
            selectedSessionID = session.id
            statusMessage = "Analyse erstellt"
            _ = try await store.loadAnalysisSession(session.id)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    func reloadActiveSession(store: AppDataStore) async {
        guard let selectedSessionID else { return }
        do {
            _ = try await store.loadAnalysisSession(selectedSessionID)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func createMarker(
        store: AppDataStore,
        at timeSeconds: Double,
        categoryID: UUID?,
        comment: String,
        playerID: UUID?
    ) async {
        guard let selectedSessionID else { return }
        do {
            _ = try await store.addMarker(
                sessionID: selectedSessionID,
                timeSeconds: timeSeconds,
                categoryID: categoryID,
                comment: comment,
                playerID: playerID
            )
            statusMessage = "Marker gespeichert"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func deleteMarker(_ markerID: UUID, store: AppDataStore) async {
        do {
            try await store.deleteMarker(markerID: markerID)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func toggleClipBoundary(currentTime: Double) {
        if clipStartTime == nil {
            clipStartTime = currentTime
            statusMessage = "Clip-Start gesetzt"
        } else {
            statusMessage = "Clip-Ende setzen und speichern"
        }
    }

    func createClip(
        store: AppDataStore,
        name: String,
        startSeconds: Double,
        endSeconds: Double,
        playerIDs: [UUID],
        note: String
    ) async {
        guard let selectedSessionID else { return }
        do {
            let clip = try await store.createClip(
                sessionID: selectedSessionID,
                name: name,
                startSeconds: startSeconds,
                endSeconds: endSeconds,
                playerIDs: playerIDs,
                note: note
            )
            selectedClipID = clip.id
            if compareClipLeftID == nil { compareClipLeftID = clip.id }
            if compareClipRightID == nil { compareClipRightID = clip.id }
            statusMessage = "Clip gespeichert"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func deleteClip(_ clipID: UUID, store: AppDataStore) async {
        do {
            try await store.deleteClip(clipID: clipID)
            if selectedClipID == clipID {
                selectedClipID = nil
            }
            if compareClipLeftID == clipID {
                compareClipLeftID = nil
            }
            if compareClipRightID == clipID {
                compareClipRightID = nil
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func shareClip(_ clipID: UUID, to playerIDs: [UUID], message: String, store: AppDataStore) async {
        do {
            try await store.shareClip(
                AnalysisShareRequest(
                    clipID: clipID,
                    playerIDs: playerIDs,
                    threadID: nil,
                    message: message
                )
            )
            statusMessage = "Clip geteilt"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func applyDrawings(_ drawings: [AnalysisDrawing], store: AppDataStore) async {
        guard let selectedSessionID else { return }
        do {
            try await store.saveDrawings(sessionID: selectedSessionID, drawings: drawings)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    #if os(macOS)
    func moveSelection(by direction: MoveCommandDirection, markers: [AnalysisMarker], clips: [AnalysisClip]) {
        switch direction {
        case .up, .left:
            if let selectedMarkerID,
               let currentIndex = markers.firstIndex(where: { $0.id == selectedMarkerID }),
               currentIndex > 0 {
                self.selectedMarkerID = markers[currentIndex - 1].id
            } else if let selectedClipID,
                      let currentIndex = clips.firstIndex(where: { $0.id == selectedClipID }),
                      currentIndex > 0 {
                self.selectedClipID = clips[currentIndex - 1].id
            }
        case .down, .right:
            if let selectedMarkerID,
               let currentIndex = markers.firstIndex(where: { $0.id == selectedMarkerID }),
               currentIndex < markers.count - 1 {
                self.selectedMarkerID = markers[currentIndex + 1].id
            } else if let selectedClipID,
                      let currentIndex = clips.firstIndex(where: { $0.id == selectedClipID }),
                      currentIndex < clips.count - 1 {
                self.selectedClipID = clips[currentIndex + 1].id
            }
        default:
            break
        }
    }
    #endif
}
