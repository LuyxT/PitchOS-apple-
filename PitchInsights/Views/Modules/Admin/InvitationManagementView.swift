import SwiftUI

struct InvitationManagementView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: InvitationManagementViewModel

    private var invitations: [AdminInvitation] {
        viewModel.filteredInvitations(from: dataStore.adminInvitations)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("Einladung suchen", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)
                Picker("Status", selection: $viewModel.selectedStatus) {
                    Text("Alle").tag(Optional<AdminInvitationStatus>.none)
                    ForEach(AdminInvitationStatus.allCases) { status in
                        Text(status.title).tag(Optional(status))
                    }
                }
                .frame(width: 200)
                Spacer()
                Button("Einladung") {
                    viewModel.showComposer = true
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }

            invitationTable
        }
        .padding(12)
        .popover(isPresented: $viewModel.showComposer) {
            InvitationComposerPopover(viewModel: viewModel)
                .environmentObject(dataStore)
        }
    }

    @ViewBuilder
    private var invitationTable: some View {
        #if os(macOS)
        Table(invitations) {
            TableColumn("Name") { invitation in
                Text(invitation.recipientName)
                    .foregroundStyle(AppTheme.textPrimary)
                    .contextMenu {
                        contextMenu(for: invitation)
                    }
            }
            TableColumn("E-Mail") { invitation in
                Text(invitation.email)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Rolle") { invitation in
                Text(invitation.role.title)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Team") { invitation in
                Text(invitation.teamName)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            TableColumn("Status") { invitation in
                Text(invitation.status.title)
                    .foregroundStyle(color(for: invitation.status))
            }
            TableColumn("Ablauf") { invitation in
                Text(DateFormatters.shortDate.string(from: invitation.expiresAt))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        #else
        List {
            ForEach(invitations) { invitation in
                VStack(alignment: .leading, spacing: 2) {
                    Text(invitation.recipientName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(invitation.role.title) • \(invitation.status.title)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .contextMenu {
                    contextMenu(for: invitation)
                }
            }
        }
        #endif
    }

    private func contextMenu(for invitation: AdminInvitation) -> some View {
        Group {
            if invitation.status == .open || invitation.status == .expired {
                Button("Erneut senden") {
                    Task { await viewModel.resend(invitation, store: dataStore) }
                }
            }
            if invitation.status != .revoked {
                Button("Zurückziehen", role: .destructive) {
                    Task { await viewModel.revoke(invitation, store: dataStore) }
                }
            }
        }
    }

    private func color(for status: AdminInvitationStatus) -> Color {
        switch status {
        case .open:
            return AppTheme.primary
        case .accepted:
            return .blue
        case .expired:
            return .orange
        case .revoked:
            return .red
        }
    }
}

private struct InvitationComposerPopover: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: InvitationManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Einladung erstellen")
                .font(.system(size: 14, weight: .semibold))

            TextField("Name", text: $viewModel.draft.recipientName)
                .textFieldStyle(.roundedBorder)
            TextField("E-Mail", text: $viewModel.draft.email)
                .textFieldStyle(.roundedBorder)
            Picker("Methode", selection: $viewModel.draft.method) {
                ForEach(AdminInvitationMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }
            Picker("Rolle", selection: $viewModel.draft.role) {
                ForEach(AdminRole.allCases) { role in
                    Text(role.title).tag(role)
                }
            }
            TextField("Team", text: $viewModel.draft.teamName)
                .textFieldStyle(.roundedBorder)
            DatePicker("Ablauf", selection: $viewModel.draft.expiresAt, displayedComponents: [.date, .hourAndMinute])

            HStack {
                Button("Abbrechen") {
                    viewModel.showComposer = false
                }
                .buttonStyle(SecondaryActionButtonStyle())
                Spacer()
                Button("Senden") {
                    let sender = dataStore.messengerCurrentUser?.displayName ?? dataStore.profile.name
                    Task { await viewModel.sendInvitation(sentBy: sender, store: dataStore) }
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
        .padding(14)
        .frame(width: 360)
        .background(AppTheme.surface)
    }
}

