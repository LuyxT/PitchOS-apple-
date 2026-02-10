import SwiftUI

struct TrainingGroupAssignmentView: View {
    let players: [Player]
    let groups: [TrainingGroup]
    @Binding var selectedGroupID: UUID?
    @Binding var groupName: String
    @Binding var groupGoal: String
    @Binding var headCoachUserID: String
    @Binding var assistantCoachUserID: String
    @Binding var selectedPlayerIDs: Set<UUID>

    let onSelectGroup: (UUID?) -> Void
    let onTogglePlayer: (UUID) -> Void
    let onSaveGroup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gruppen & Trainer")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Picker("Gruppe", selection: $selectedGroupID) {
                Text("Neue Gruppe").tag(Optional<UUID>.none)
                ForEach(groups) { group in
                    Text(group.name).tag(Optional(group.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .onChange(of: selectedGroupID) { _, value in
                onSelectGroup(value)
            }

            TextField("Gruppenname", text: $groupName)
                .textFieldStyle(.roundedBorder)
            TextField("Gruppenziel", text: $groupGoal)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                TextField("Haupttrainer User-ID", text: $headCoachUserID)
                    .textFieldStyle(.roundedBorder)
                TextField("Co-Trainer User-ID", text: $assistantCoachUserID)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Spielerzuordnung")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(players) { player in
                            Button {
                                onTogglePlayer(player.id)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: selectedPlayerIDs.contains(player.id) ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(selectedPlayerIDs.contains(player.id) ? AppTheme.primary : AppTheme.textSecondary)
                                    Text("#\(player.number) \(player.name)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color.black)
                                    Spacer()
                                    Text(player.position)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selectedPlayerIDs.contains(player.id) ? AppTheme.primary.opacity(0.14) : AppTheme.surface)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }

            Button("Gruppe speichern", action: onSaveGroup)
                .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }
}
