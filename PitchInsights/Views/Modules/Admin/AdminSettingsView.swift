import SwiftUI

struct AdminSettingsView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var settingsDraft: AdminClubSettings = .default
    @State private var messengerRulesDraft: AdminMessengerRules = .default
    @State private var statusMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                clubSettingsCard
                messengerRulesCard
                if let statusMessage, !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(12)
        }
        .onAppear {
            settingsDraft = dataStore.adminClubSettings
            messengerRulesDraft = dataStore.adminMessengerRules
        }
    }

    private var clubSettingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Vereinseinstellungen")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            TextField("Vereinsname", text: $settingsDraft.clubName)
                .textFieldStyle(.roundedBorder)
            TextField("Logo-Pfad", text: $settingsDraft.clubLogoPath)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                TextField("Primärfarbe (Hex)", text: $settingsDraft.primaryColorHex)
                    .textFieldStyle(.roundedBorder)
                TextField("Sekundärfarbe (Hex)", text: $settingsDraft.secondaryColorHex)
                    .textFieldStyle(.roundedBorder)
            }
            TextField("Team-Namenskonvention", text: $settingsDraft.teamNameConvention)
                .textFieldStyle(.roundedBorder)
            TextField(
                "Standard-Trainingstypen (Komma getrennt)",
                text: Binding(
                    get: { settingsDraft.standardTrainingTypes.joined(separator: ", ") },
                    set: {
                        settingsDraft.standardTrainingTypes = $0
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                    }
                )
            )
            .textFieldStyle(.roundedBorder)
            TextField("Standard-Sichtbarkeit", text: $settingsDraft.defaultVisibility)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Globale Berechtigungen")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                ForEach(AdminPermission.allCases) { permission in
                    Toggle(isOn: Binding(
                        get: { settingsDraft.globalPermissions.contains(permission) },
                        set: { isOn in
                            if isOn {
                                settingsDraft.globalPermissions.insert(permission)
                            } else {
                                settingsDraft.globalPermissions.remove(permission)
                            }
                        }
                    )) {
                        Text(permission.title)
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .adminCheckboxStyle()
                }
            }

            HStack {
                Spacer()
                Button("Vereinseinstellungen speichern") {
                    Task {
                        do {
                            try await dataStore.saveAdminClubSettings(settingsDraft)
                            statusMessage = "Vereinseinstellungen gespeichert."
                        } catch {
                            statusMessage = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var messengerRulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kommunikations-Regelwerk")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Toggle("Spieler dürfen privat chatten", isOn: $messengerRulesDraft.allowPrivatePlayerChat)
                .toggleStyle(.switch)
                .foregroundStyle(AppTheme.textPrimary)
            Toggle("Trainer ↔ Spieler Direktchat erlaubt", isOn: $messengerRulesDraft.allowDirectTrainerPlayerChat)
                .toggleStyle(.switch)
                .foregroundStyle(AppTheme.textPrimary)
            Toggle("Gruppen standardmäßig nur lesen (Spieler)", isOn: $messengerRulesDraft.defaultReadOnlyForPlayers)
                .toggleStyle(.switch)
                .foregroundStyle(AppTheme.textPrimary)

            TextField(
                "Erlaubte Chat-Typen (Komma getrennt)",
                text: Binding(
                    get: { messengerRulesDraft.allowedChatTypes.joined(separator: ", ") },
                    set: {
                        messengerRulesDraft.allowedChatTypes = $0
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                    }
                )
            )
            .textFieldStyle(.roundedBorder)

            TextField(
                "Standardgruppen (Komma getrennt)",
                text: Binding(
                    get: { messengerRulesDraft.defaultGroups.joined(separator: ", ") },
                    set: {
                        messengerRulesDraft.defaultGroups = $0
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                    }
                )
            )
            .textFieldStyle(.roundedBorder)

            TextField("Gruppenregeln", text: $messengerRulesDraft.groupRuleDescription, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Messenger-Regeln speichern") {
                    Task {
                        do {
                            try await dataStore.saveAdminMessengerRules(messengerRulesDraft)
                            statusMessage = "Messenger-Regeln gespeichert."
                        } catch {
                            statusMessage = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
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
