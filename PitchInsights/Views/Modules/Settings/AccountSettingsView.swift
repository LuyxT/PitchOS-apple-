import SwiftUI

struct AccountSettingsView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: AccountSettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            contextCard
            actionsCard
        }
        .onAppear {
            viewModel.load(store: dataStore)
        }
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rollen und Vereinskontext")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black)

            Picker("Aktiver Kontext", selection: Binding(
                get: { viewModel.state.selectedContextID },
                set: { value in
                    guard let value else { return }
                    Task { await viewModel.switchContext(value, store: dataStore) }
                }
            )) {
                ForEach(viewModel.state.contexts) { context in
                    Text(context.displayTitle).tag(Optional(context.id))
                }
            }
            .pickerStyle(.menu)
            .foregroundStyle(Color.black)
        }
        .padding(12)
        .background(cardBackground)
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account & Logout")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black)

            HStack(spacing: 10) {
                Button("Abmelden") {
                    viewModel.logout(store: dataStore)
                }
                .buttonStyle(SecondaryActionButtonStyle())

                if viewModel.state.canLeaveTeam {
                    Button("Team verlassen") {
                        Task { await viewModel.leaveTeam(store: dataStore) }
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(viewModel.isBusy)
                }

                if viewModel.state.canDeactivateAccount {
                    Button("Konto deaktivieren", role: .destructive) {
                        Task { await viewModel.deactivate(store: dataStore) }
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(viewModel.isBusy)
                }
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}
