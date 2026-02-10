import SwiftUI

struct SecuritySettingsView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.openURL) private var openURL
    @ObservedObject var viewModel: SecuritySettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            passwordCard
            twoFactorCard
            sessionsCard
            tokensCard
            privacyCard
        }
        .onAppear {
            viewModel.load(store: dataStore)
        }
    }

    private var passwordCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Passwort ändern")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black)

            SecureField("Aktuelles Passwort", text: $viewModel.currentPassword)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(Color.black)
            SecureField("Neues Passwort", text: $viewModel.newPassword)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(Color.black)
            SecureField("Neues Passwort bestätigen", text: $viewModel.confirmPassword)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(Color.black)

            HStack {
                Spacer()
                Button("Passwort aktualisieren") {
                    Task { await viewModel.changePassword(store: dataStore) }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(viewModel.isBusy)
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var twoFactorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Zwei-Faktor-Authentifizierung")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black)

            Toggle("Zwei-Faktor aktivieren", isOn: Binding(
                get: { viewModel.state.twoFactorEnabled },
                set: { value in
                    Task { await viewModel.setTwoFactor(value, store: dataStore) }
                }
            ))
            .toggleStyle(.switch)
            .foregroundStyle(Color.black)
            .disabled(viewModel.isBusy)
        }
        .padding(12)
        .background(cardBackground)
    }

    private var sessionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Aktive Sessions")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.black)
                Spacer()
                Button("Aktualisieren") {
                    Task { await viewModel.refresh(store: dataStore) }
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(viewModel.isBusy)
            }

            if viewModel.state.sessions.isEmpty {
                Text("Keine Sessions verfügbar.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.58))
            } else {
                ForEach(viewModel.state.sessions) { session in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.deviceName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.black)
                            Text("\(session.platformName) • \(session.location) • \(session.ipAddress)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.58))
                            Text(session.lastUsedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(Color.black.opacity(0.52))
                        }
                        Spacer()
                        if session.isCurrentDevice {
                            Text("Aktuelles Gerät")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryDark)
                        } else {
                            Button("Beenden") {
                                Task { await viewModel.revokeSession(session, store: dataStore) }
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                            .disabled(viewModel.isBusy)
                        }
                    }
                    .padding(.vertical, 6)
                    if session.id != viewModel.state.sessions.last?.id {
                        Divider()
                    }
                }

                HStack {
                    Spacer()
                    Button("Von allen anderen Geräten abmelden") {
                        Task { await viewModel.revokeAllSessions(store: dataStore) }
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(viewModel.isBusy)
                }
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var tokensCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API-/Token-Zugriffe")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black)
            if viewModel.state.apiTokens.isEmpty {
                Text("Keine aktiven Tokens.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.58))
            } else {
                ForEach(viewModel.state.apiTokens) { token in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(token.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.black)
                            Text(token.scope)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.black.opacity(0.58))
                        }
                        Spacer()
                        Text(token.lastUsedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Nie verwendet")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.62))
                    }
                    .padding(.vertical, 6)
                    if token.id != viewModel.state.apiTokens.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Datenschutz")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black)
            Button("Datenschutzrichtlinie öffnen") {
                guard let url = URL(string: viewModel.state.privacyURL) else { return }
                openURL(url)
            }
            .buttonStyle(SecondaryActionButtonStyle())
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
