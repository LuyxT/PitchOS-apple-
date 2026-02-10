import Foundation

@MainActor
final class SettingsService {
    func bootstrap(store: AppDataStore) async {
        await store.bootstrapSettings()
        await store.bootstrapProfiles()
    }

    func saveProfile(_ profile: PersonProfile, store: AppDataStore) async throws -> PersonProfile {
        try await store.upsertProfile(profile)
    }

    func savePresentation(_ settings: AppPresentationSettings, store: AppDataStore) async throws {
        try await store.savePresentationSettings(settings)
    }

    func saveNotifications(_ settings: NotificationSettingsState, store: AppDataStore) async throws {
        try await store.saveNotificationSettings(settings)
    }

    func refreshSecurity(store: AppDataStore) async {
        await store.refreshSecuritySettings()
    }

    func changePassword(
        currentPassword: String,
        newPassword: String,
        store: AppDataStore
    ) async throws {
        try await store.changePassword(currentPassword: currentPassword, newPassword: newPassword)
    }

    func updateTwoFactor(enabled: Bool, store: AppDataStore) async throws {
        try await store.updateTwoFactor(enabled: enabled)
    }

    func revokeSession(_ session: SecuritySessionInfo, store: AppDataStore) async throws {
        try await store.revokeSecuritySession(session)
    }

    func revokeAllSessions(store: AppDataStore) async throws {
        try await store.revokeAllSecuritySessions()
    }

    func refreshAppInfo(store: AppDataStore) async {
        await store.refreshAppInfoSettings()
    }

    func submitFeedback(_ payload: SettingsFeedbackPayload, store: AppDataStore) async throws {
        try await store.submitSettingsFeedback(payload)
    }

    func switchContext(_ contextID: UUID, store: AppDataStore) async throws {
        try await store.switchAccountContext(to: contextID)
    }

    func deactivateAccount(store: AppDataStore) async throws {
        try await store.deactivateCurrentAccount()
    }

    func leaveTeam(store: AppDataStore) async throws {
        try await store.leaveCurrentTeam()
    }

    func logout(store: AppDataStore) {
        store.logoutCurrentAccount()
    }
}
