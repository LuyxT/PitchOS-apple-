import SwiftUI

struct AdminWorkspaceView: View {
    @EnvironmentObject private var dataStore: AppDataStore

    @StateObject private var workspaceViewModel = AdminWorkspaceViewModel()
    @StateObject private var dashboardViewModel = AdminDashboardViewModel()
    @StateObject private var userViewModel = UserManagementViewModel()
    @StateObject private var roleViewModel = RoleManagementViewModel()
    @StateObject private var groupViewModel = GroupManagementViewModel()
    @StateObject private var seasonViewModel = SeasonManagementViewModel()
    @StateObject private var invitationViewModel = InvitationManagementViewModel()
    @StateObject private var auditViewModel = AuditLogViewModel()

    private var statusMessage: String? {
        workspaceViewModel.statusMessage
            ?? userViewModel.statusMessage
            ?? roleViewModel.statusMessage
            ?? groupViewModel.statusMessage
            ?? seasonViewModel.statusMessage
            ?? invitationViewModel.statusMessage
            ?? auditViewModel.statusMessage
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            sectionPicker
            Divider()
            content
            if let statusMessage, !statusMessage.isEmpty {
                HStack {
                    Text(statusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
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
        }
        .background(AppTheme.background)
        .environment(\.colorScheme, .light)
        .onAppear {
            Task {
                await workspaceViewModel.bootstrap(store: dataStore)
                dashboardViewModel.refresh(store: dataStore)
                await auditViewModel.apply(store: dataStore)
            }
        }
        .onChange(of: dataStore.adminPersons) { _, _ in
            dashboardViewModel.refresh(store: dataStore)
        }
        .onChange(of: dataStore.adminInvitations) { _, _ in
            dashboardViewModel.refresh(store: dataStore)
        }
        .onChange(of: dataStore.adminGroups) { _, _ in
            dashboardViewModel.refresh(store: dataStore)
        }
        .onReceive(NotificationCenter.default.publisher(for: .adminCommandNewPerson)) { _ in
            workspaceViewModel.selectedSection = .users
            userViewModel.beginCreate(defaultTeam: dataStore.profile.team)
        }
        .onReceive(NotificationCenter.default.publisher(for: .adminCommandNewGroup)) { _ in
            workspaceViewModel.selectedSection = .groups
            groupViewModel.beginCreate()
        }
        .onReceive(NotificationCenter.default.publisher(for: .adminCommandNewInvitation)) { _ in
            workspaceViewModel.selectedSection = .invitations
            invitationViewModel.showComposer = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .adminCommandRefresh)) { _ in
            Task {
                await workspaceViewModel.bootstrap(store: dataStore)
                dashboardViewModel.refresh(store: dataStore)
                await auditViewModel.apply(store: dataStore)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                Task {
                    await workspaceViewModel.bootstrap(store: dataStore)
                    dashboardViewModel.refresh(store: dataStore)
                    await auditViewModel.apply(store: dataStore)
                }
            } label: {
                Label("Aktualisieren", systemImage: "arrow.clockwise")
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Button {
                workspaceViewModel.selectedSection = .users
                userViewModel.beginCreate(defaultTeam: dataStore.profile.team)
            } label: {
                Label("Person", systemImage: "person.badge.plus")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .keyboardShortcut("n", modifiers: [.command])

            Button {
                workspaceViewModel.selectedSection = .groups
                groupViewModel.beginCreate()
            } label: {
                Label("Gruppe", systemImage: "person.3.sequence")
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Button {
                workspaceViewModel.selectedSection = .invitations
                invitationViewModel.showComposer = true
            } label: {
                Label("Einladen", systemImage: "envelope.badge")
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Spacer()

            Text(connectionLabel)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(connectionColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(connectionColor.opacity(0.12))
                )
        }
        .padding(12)
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AdminSection.allCases) { section in
                    if section == workspaceViewModel.selectedSection {
                        Button(section.title) {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                workspaceViewModel.selectedSection = section
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    } else {
                        Button(section.title) {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                workspaceViewModel.selectedSection = section
                            }
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch workspaceViewModel.selectedSection {
        case .dashboard:
            AdminDashboardView(
                viewModel: dashboardViewModel,
                onOpenInvitations: { workspaceViewModel.selectedSection = .invitations },
                onOpenRights: { workspaceViewModel.selectedSection = .roles }
            )
        case .users:
            UserManagementView(viewModel: userViewModel)
        case .roles:
            RoleManagementView(viewModel: roleViewModel)
        case .groups:
            GroupManagementView(viewModel: groupViewModel)
        case .seasons:
            SeasonManagementView(viewModel: seasonViewModel)
        case .invitations:
            InvitationManagementView(viewModel: invitationViewModel)
        case .audit:
            AuditLogView(viewModel: auditViewModel)
        case .settings:
            AdminSettingsView()
        }
    }

    private var connectionLabel: String {
        switch dataStore.adminConnectionState {
        case .placeholder:
            return "Lokal"
        case .syncing:
            return "Sync läuft"
        case .live:
            return "Live"
        case .failed:
            return "Fehler"
        }
    }

    private var connectionColor: Color {
        switch dataStore.adminConnectionState {
        case .placeholder:
            return .orange
        case .syncing:
            return .blue
        case .live:
            return AppTheme.primary
        case .failed:
            return .red
        }
    }
}
