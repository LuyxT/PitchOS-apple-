import Foundation
import Combine

@MainActor
final class DisplaySettingsViewModel: ObservableObject {
    @Published var draft: AppPresentationSettings = .default
    @Published var isSaving = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let service = SettingsService()

    var timeZoneIDs: [String] {
        let prioritized = [
            TimeZone.current.identifier,
            "Europe/Berlin",
            "Europe/Zurich",
            "Europe/Vienna",
            "UTC",
            "America/New_York",
            "America/Los_Angeles"
        ]
        var combined = prioritized + TimeZone.knownTimeZoneIdentifiers
        combined = Array(Set(combined)).sorted()
        return combined
    }

    func load(store: AppDataStore) {
        draft = store.settingsPresentation
    }

    func save(store: AppDataStore) async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await service.savePresentation(draft, store: store)
            statusMessage = "Darstellung gespeichert."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }
}
