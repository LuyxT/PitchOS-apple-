import Foundation
import Combine

@MainActor
final class ProfileSettingsViewModel: ObservableObject {
    @Published var draftProfile: PersonProfile?
    @Published var permissionSnapshot: ProfilePermissionSnapshot = .none
    @Published var contexts: [AccountContext] = []
    @Published var selectedContextID: UUID?
    @Published var isSaving = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let service = SettingsService()
    private let validator = SettingsValidationService()
    private let permissionService = ProfilePermissionService()

    func load(store: AppDataStore) {
        let viewer = store.currentViewerProfile()
        draftProfile = viewer
        contexts = store.settingsAccount.contexts
        selectedContextID = store.settingsAccount.selectedContextID

        if let viewer {
            let permissions = viewer.linkedAdminPersonID
                .flatMap { id in
                    store.adminPersons.first(where: { $0.id == id })?.permissions
                } ?? []
            permissionSnapshot = permissionService.permissionSnapshot(
                viewer: viewer,
                viewerAdminPermissions: permissions,
                target: viewer
            )
        } else {
            permissionSnapshot = .none
        }
    }

    func save(store: AppDataStore) async {
        guard var draftProfile else { return }
        if let emailError = validator.validateProfileEmail(draftProfile.core.email) {
            errorMessage = emailError
            statusMessage = nil
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            draftProfile.updatedBy = store.currentProfileActorName()
            let saved = try await service.saveProfile(draftProfile, store: store)
            self.draftProfile = saved
            statusMessage = "Profil gespeichert."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    func switchContext(_ id: UUID?, store: AppDataStore) async {
        guard let id else { return }
        do {
            try await service.switchContext(id, store: store)
            selectedContextID = id
            contexts = store.settingsAccount.contexts
            statusMessage = "Kontext gewechselt."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }
}

private extension ProfilePermissionSnapshot {
    static let none = ProfilePermissionSnapshot(
        canViewMedicalInternals: false,
        canViewInternalNotes: false,
        canEditCore: false,
        canEditRoles: false,
        canEditSports: false,
        canEditOwnGoalsOnly: false,
        canEditMedical: false,
        canEditResponsibilities: false,
        canDeleteProfile: false
    )
}
