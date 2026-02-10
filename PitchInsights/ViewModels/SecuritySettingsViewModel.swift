import Foundation
import Combine

@MainActor
final class SecuritySettingsViewModel: ObservableObject {
    @Published var state: SecuritySettingsState = .default
    @Published var currentPassword = ""
    @Published var newPassword = ""
    @Published var confirmPassword = ""
    @Published var isBusy = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let service = SettingsService()
    private let validator = SettingsValidationService()

    func load(store: AppDataStore) {
        state = store.settingsSecurity
    }

    func refresh(store: AppDataStore) async {
        await service.refreshSecurity(store: store)
        state = store.settingsSecurity
    }

    func changePassword(store: AppDataStore) async {
        if let validationError = validator.validatePasswordChange(
            currentPassword: currentPassword,
            newPassword: newPassword,
            confirmPassword: confirmPassword
        ) {
            errorMessage = validationError
            statusMessage = nil
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            try await service.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword,
                store: store
            )
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
            statusMessage = "Passwort geändert."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    func setTwoFactor(_ enabled: Bool, store: AppDataStore) async {
        state.twoFactorEnabled = enabled
        isBusy = true
        defer { isBusy = false }

        do {
            try await service.updateTwoFactor(enabled: enabled, store: store)
            state = store.settingsSecurity
            statusMessage = enabled ? "Zwei-Faktor aktiviert." : "Zwei-Faktor deaktiviert."
            errorMessage = nil
        } catch {
            state.twoFactorEnabled.toggle()
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    func revokeSession(_ session: SecuritySessionInfo, store: AppDataStore) async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await service.revokeSession(session, store: store)
            state = store.settingsSecurity
            statusMessage = "Session beendet."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    func revokeAllSessions(store: AppDataStore) async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await service.revokeAllSessions(store: store)
            state = store.settingsSecurity
            statusMessage = "Alle anderen Sessions beendet."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }
}
