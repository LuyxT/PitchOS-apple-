import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(spacing: 0) {
                personListPane
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
                Divider()
                detailPane
            }
            statusFooter
        }
        .background(AppTheme.background)
        .environment(\.colorScheme, .light)
        .task {
            await viewModel.bootstrap(store: dataStore)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            TextField("Person suchen", text: $viewModel.filter.search)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .foregroundStyle(Color.black)

            Picker("Rolle", selection: $viewModel.filter.role) {
                Text("Alle Rollen").tag(Optional<ProfileRoleType>.none)
                ForEach(ProfileRoleType.allCases) { role in
                    Text(role.title).tag(Optional(role))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 190)
            .foregroundStyle(Color.black)

            Toggle("Inaktiv einblenden", isOn: $viewModel.filter.includeInactive)
                .toggleStyle(.switch)
                .foregroundStyle(Color.black)

            Spacer()

            Button {
                viewModel.beginCreateProfile(defaultClubName: dataStore.profile.team)
            } label: {
                Label("Neu", systemImage: "plus")
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .keyboardShortcut("n", modifiers: [.command])

            Button {
                Task { await viewModel.bootstrap(store: dataStore) }
            } label: {
                Label("Aktualisieren", systemImage: "arrow.clockwise")
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surface)
    }

    private var personListPane: some View {
        let profiles = viewModel.filteredProfiles(store: dataStore)
        return VStack(spacing: 0) {
            #if os(macOS)
            Table(
                profiles,
                selection: Binding(
                    get: { viewModel.selectedProfileID },
                    set: { newValue in
                        Task { await viewModel.selectProfile(newValue, store: dataStore) }
                    }
                )
            ) {
                TableColumn("Name") { item in
                    Text(item.displayName)
                        .foregroundStyle(Color.black)
                }
                TableColumn("Rolle") { item in
                    Text(item.core.roles.first?.title ?? "-")
                        .foregroundStyle(Color.black)
                }
                TableColumn("Aktiv") { item in
                    Text(item.core.isActive ? "Ja" : "Nein")
                        .foregroundStyle(item.core.isActive ? AppTheme.primaryDark : Color.black.opacity(0.55))
                }
            }
            #else
            List(profiles, selection: Binding(
                get: { viewModel.selectedProfileID },
                set: { newValue in
                    Task { await viewModel.selectProfile(newValue, store: dataStore) }
                }
            )) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.displayName)
                        .foregroundStyle(Color.black)
                    Text(item.core.roles.first?.title ?? "-")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.black.opacity(0.6))
                }
            }
            .listStyle(.plain)
            #endif
        }
        .background(AppTheme.surface)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let draft = viewModel.draftProfile {
            let permissions = viewModel.permissionSnapshot(store: dataStore, target: draft)
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(draft.displayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.black)
                        Text(draft.core.roles.map(\.title).joined(separator: ", "))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.6))
                    }
                    Spacer()
                    if permissions.canDeleteProfile {
                        Button("Löschen", role: .destructive) {
                            Task { await viewModel.deleteSelected(store: dataStore) }
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .disabled(viewModel.isSaving || viewModel.selectedProfileID == nil)
                    }
                    Button("Speichern") {
                        Task { await viewModel.saveDraft(store: dataStore) }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(viewModel.isSaving)
                }
                .padding(12)
                .background(AppTheme.surface)

                RoleBasedProfileView(
                    profile: Binding(
                        get: { viewModel.draftProfile ?? draft },
                        set: { viewModel.draftProfile = $0 }
                    ),
                    permissions: permissions
                )
                .background(AppTheme.background)

                auditPanel
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(AppTheme.primary)
                Text("Kein Profil ausgewählt")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.black)
                Text("Wähle links eine Person oder lege ein neues Profil an.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.black.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var auditPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Änderungsverlauf")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.black)
            if viewModel.auditEntries.isEmpty {
                Text("Keine Einträge")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.black.opacity(0.58))
            } else {
                ForEach(viewModel.auditEntries.prefix(6)) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.actionLine)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.black)
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 10))
                                .foregroundStyle(Color.black.opacity(0.5))
                        }
                        Spacer()
                        Text(entry.area.title)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryDark)
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }

    private var statusFooter: some View {
        HStack {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Text(viewModel.errorText ?? viewModel.statusText ?? "")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(viewModel.errorText == nil ? AppTheme.textSecondary : .red)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(AppTheme.border).frame(height: 1)
        }
    }
}

private extension ProfileAuditEntry {
    var actionLine: String {
        if oldValue == "-" {
            return "\(actorName): \(newValue)"
        }
        return "\(actorName): \(fieldPath) geändert"
    }
}
