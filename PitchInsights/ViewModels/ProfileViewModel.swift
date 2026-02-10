import Foundation
import SwiftUI
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var filter = ProfileFilter()
    @Published var selectedProfileID: UUID?
    @Published var draftProfile: PersonProfile?
    @Published var auditEntries: [ProfileAuditEntry] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var statusText: String?
    @Published var errorText: String?

    let permissionService = ProfilePermissionService()

    func bootstrap(store: AppDataStore) async {
        isLoading = true
        defer { isLoading = false }
        await store.bootstrapAdministration()
        await store.bootstrapProfiles()
        selectedProfileID = store.activePersonProfileID ?? store.personProfiles.first?.id
        if let selectedProfileID,
           let profile = store.profile(with: selectedProfileID) {
            draftProfile = profile
            await store.loadProfileAudit(profileID: selectedProfileID)
            auditEntries = store.profileAuditEntries
        } else {
            draftProfile = nil
            auditEntries = []
        }
        errorText = nil
    }

    func filteredProfiles(store: AppDataStore) -> [PersonProfile] {
        let query = filter.search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.personProfiles
            .filter { profile in
                if !filter.includeInactive && !profile.core.isActive {
                    return false
                }
                if let role = filter.role, !profile.core.roles.contains(role) {
                    return false
                }
                guard !query.isEmpty else { return true }
                if profile.displayName.lowercased().contains(query) { return true }
                if profile.core.email.lowercased().contains(query) { return true }
                if profile.core.clubName.lowercased().contains(query) { return true }
                let roles = profile.core.roles.map(\.title).joined(separator: " ").lowercased()
                return roles.contains(query)
            }
            .sorted { $0.displayName < $1.displayName }
    }

    func selectProfile(_ profileID: UUID?, store: AppDataStore) async {
        selectedProfileID = profileID
        guard let profileID,
              let profile = store.profile(with: profileID) else {
            draftProfile = nil
            auditEntries = []
            return
        }
        draftProfile = profile
        await store.loadProfileAudit(profileID: profileID)
        auditEntries = store.profileAuditEntries
        errorText = nil
    }

    func beginCreateProfile(defaultClubName: String) {
        draftProfile = PersonProfile(
            core: ProfileCoreData(
                avatarPath: nil,
                firstName: "",
                lastName: "",
                dateOfBirth: nil,
                email: "",
                phone: "",
                clubName: defaultClubName,
                roles: [.player],
                isActive: true,
                internalNotes: ""
            ),
            player: PlayerRoleProfileData(
                primaryPosition: .zm,
                secondaryPositions: [],
                jerseyNumber: nil,
                heightCm: nil,
                weightKg: nil,
                preferredFoot: nil,
                preferredSystemRole: "",
                seasonGoals: "",
                longTermGoals: "",
                pathway: "",
                loadCapacity: .free,
                injuryHistory: "",
                availability: .fit
            ),
            updatedBy: "Lokaler Benutzer"
        )
        statusText = "Neues Profil erstellt."
        errorText = nil
    }

    func permissionSnapshot(store: AppDataStore, target: PersonProfile?) -> ProfilePermissionSnapshot {
        guard let target else {
            return ProfilePermissionSnapshot(
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
        let viewer = store.currentViewerProfile()
        let adminPermissions = viewer
            .flatMap { view in
                store.adminPersons.first(where: { $0.id == view.linkedAdminPersonID })?.permissions
            } ?? []
        return permissionService.permissionSnapshot(
            viewer: viewer,
            viewerAdminPermissions: adminPermissions,
            target: target
        )
    }

    func saveDraft(store: AppDataStore) async {
        guard var draftProfile else { return }
        let name = draftProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorText = "Vorname und Nachname sind erforderlich."
            return
        }
        guard !draftProfile.core.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorText = "E-Mail ist erforderlich."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            draftProfile.updatedBy = store.currentViewerProfile()?.displayName ?? "Lokaler Benutzer"
            let saved = try await store.upsertProfile(draftProfile)
            selectedProfileID = saved.id
            self.draftProfile = saved
            await store.loadProfileAudit(profileID: saved.id)
            auditEntries = store.profileAuditEntries
            statusText = "Profil gespeichert."
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    func deleteSelected(store: AppDataStore) async {
        guard let selectedProfileID else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.deleteProfile(selectedProfileID)
            let next = filteredProfiles(store: store).first?.id
            await selectProfile(next, store: store)
            statusText = "Profil entfernt."
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}
