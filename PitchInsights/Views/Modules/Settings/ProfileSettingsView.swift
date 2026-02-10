import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @ObservedObject var viewModel: ProfileSettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerCard

            if let draftProfile = viewModel.draftProfile {
                RoleBasedProfileView(
                    profile: Binding(
                        get: { viewModel.draftProfile ?? draftProfile },
                        set: { viewModel.draftProfile = $0 }
                    ),
                    permissions: viewModel.permissionSnapshot
                )
                .frame(minHeight: 520)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(AppTheme.primary)
                    Text("Kein persönliches Profil verfügbar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
            }
        }
        .onAppear {
            viewModel.load(store: dataStore)
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppTheme.primary.opacity(0.18))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(initials)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.primaryDark)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.black)
                Text(roleTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.62))
            }

            Spacer()

            Picker("Kontext", selection: Binding(
                get: { viewModel.selectedContextID },
                set: { value in
                    Task { await viewModel.switchContext(value, store: dataStore) }
                }
            )) {
                ForEach(viewModel.contexts) { context in
                    Text(context.displayTitle).tag(Optional(context.id))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 320)
            .foregroundStyle(Color.black)

            Button {
                Task { await viewModel.save(store: dataStore) }
            } label: {
                Label("Profil speichern", systemImage: "checkmark")
                    .foregroundStyle(Color.black)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(viewModel.isSaving || viewModel.draftProfile == nil)
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }

    private var displayName: String {
        viewModel.draftProfile?.displayName ?? "Nutzer"
    }

    private var roleTitle: String {
        let titles = viewModel.draftProfile?.core.roles.map(\.title) ?? []
        return titles.isEmpty ? "Keine Rolle" : titles.joined(separator: ", ")
    }

    private var initials: String {
        let name = displayName
        let tokens = name
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
        return tokens.isEmpty ? "PI" : tokens.joined()
    }
}
