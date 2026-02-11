import Foundation
import Combine

@MainActor
final class AccountSettingsViewModel: ObservableObject {
    @Published var state: AccountSettingsState = .default
    @Published var isBusy = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let service = SettingsService()

    func load(store: AppDataStore) {
        state = store.settingsAccount
    }

    func switchContext(_ id: UUID, store: AppDataStore) async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await service.switchContext(id, store: store)
            state = store.settingsAccount
            statusMessage = "Kontext gewechselt."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    func logout(store: AppDataStore) async {
        await service.logout(store: store)
        statusMessage = "Abgemeldet."
        errorMessage = nil
    }

    func deactivate(store: AppDataStore) async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await service.deactivateAccount(store: store)
            statusMessage = "Konto deaktiviert."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    func leaveTeam(store: AppDataStore) async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await service.leaveTeam(store: store)
            statusMessage = "Team verlassen."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }
}
