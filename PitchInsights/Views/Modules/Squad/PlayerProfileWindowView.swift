import SwiftUI

struct PlayerProfileWindowView: View {
    @EnvironmentObject private var dataStore: AppDataStore

    let playerID: UUID

    @State private var draftProfile: PersonProfile?
    @State private var statusText: String?
    @State private var errorText: String?
    @State private var isSaving = false

    private let permissionService = ProfilePermissionService()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let draftProfile {
                RoleBasedProfileView(
                    profile: Binding(
                        get: { draftProfile },
                        set: { self.draftProfile = $0 }
                    ),
                    permissions: permissions(for: draftProfile)
                )
            } else {
                VStack(spacing: 10) {
                    Text("Profil nicht gefunden")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.black)
                    Text("Der Spieler ist keinem Profil zugeordnet.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.black.opacity(0.58))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            footer
        }
        .background(AppTheme.background)
        .environment(\.colorScheme, .light)
        .task {
            loadProfile()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Profil")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.black)
                Text(draftProfile?.displayName ?? "-")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.6))
            }
            Spacer()
            Button("Neu laden") {
                loadProfile()
            }
            .buttonStyle(SecondaryActionButtonStyle())
            if draftProfile != nil {
                Button("Speichern") {
                    Task { await saveProfile() }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(isSaving)
            }
        }
        .padding(12)
        .background(AppTheme.surface)
    }

    private var footer: some View {
        HStack {
            Text(errorText ?? statusText ?? "")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(errorText == nil ? AppTheme.textSecondary : .red)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }

    private func permissions(for target: PersonProfile) -> ProfilePermissionSnapshot {
        let viewer = dataStore.currentViewerProfile()
        let adminPermissions = viewer
            .flatMap { profile in
                dataStore.adminPersons.first(where: { $0.id == profile.linkedAdminPersonID })?.permissions
            } ?? []
        return permissionService.permissionSnapshot(
            viewer: viewer,
            viewerAdminPermissions: adminPermissions,
            target: target
        )
    }

    private func loadProfile() {
        if let existing = dataStore.profile(forPlayerID: playerID) {
            draftProfile = existing
            return
        }
        if let player = dataStore.player(with: playerID) {
            dataStore.syncProfileFromPlayerChange(player)
            draftProfile = dataStore.profile(forPlayerID: playerID)
        }
    }

    private func saveProfile() async {
        guard let draftProfile else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let saved = try await dataStore.upsertProfile(draftProfile)
            self.draftProfile = saved
            statusText = "Profil gespeichert."
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}
