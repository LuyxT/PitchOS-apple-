import Foundation
import Combine

struct AdminSeasonDraft {
    var localID: UUID?
    var backendID: String?
    var name: String = ""
    var startsAt: Date = Date()
    var endsAt: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    var status: AdminSeasonStatus = .locked

    init() {}

    init(from season: AdminSeason) {
        localID = season.id
        backendID = season.backendID
        name = season.name
        startsAt = season.startsAt
        endsAt = season.endsAt
        status = season.status
    }

    func materialize(existing: AdminSeason?) -> AdminSeason {
        AdminSeason(
            id: existing?.id ?? localID ?? UUID(),
            backendID: existing?.backendID ?? backendID,
            name: name,
            startsAt: startsAt,
            endsAt: endsAt,
            status: status,
            teamCount: existing?.teamCount ?? 1,
            playerCount: existing?.playerCount ?? 0,
            trainerCount: existing?.trainerCount ?? 0,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        )
    }
}

@MainActor
final class SeasonManagementViewModel: ObservableObject {
    @Published var selectedSeasonID: UUID?
    @Published var draft = AdminSeasonDraft()
    @Published var isEditorPresented = false
    @Published var isSaving = false
    @Published var statusMessage: String?

    func ensureSelection(in seasons: [AdminSeason]) {
        if let selectedSeasonID, seasons.contains(where: { $0.id == selectedSeasonID }) {
            return
        }
        selectedSeasonID = seasons.first?.id
    }

    func beginCreate() {
        draft = AdminSeasonDraft()
        isEditorPresented = true
    }

    func beginEdit(_ season: AdminSeason) {
        draft = AdminSeasonDraft(from: season)
        isEditorPresented = true
    }

    func save(store: AppDataStore) async {
        isSaving = true
        defer { isSaving = false }
        let existing = store.adminSeasons.first(where: { $0.id == draft.localID })
        let season = draft.materialize(existing: existing)
        do {
            let saved = try await store.upsertAdminSeason(season)
            selectedSeasonID = saved.id
            isEditorPresented = false
            statusMessage = "Saison gespeichert."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func setActive(store: AppDataStore) async {
        guard let selectedSeasonID else { return }
        do {
            try await store.setActiveAdminSeason(selectedSeasonID)
            statusMessage = "Saison aktiviert."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func archiveSelected(store: AppDataStore) async {
        guard let selectedSeasonID else { return }
        do {
            try await store.archiveAdminSeason(selectedSeasonID)
            statusMessage = "Saison archiviert."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func copyRoster(from sourceSeasonID: UUID, store: AppDataStore) async {
        guard let selectedSeasonID else { return }
        do {
            try await store.duplicateRosterToSeason(sourceSeasonID: sourceSeasonID, targetSeasonID: selectedSeasonID)
            statusMessage = "Kader übernommen."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
