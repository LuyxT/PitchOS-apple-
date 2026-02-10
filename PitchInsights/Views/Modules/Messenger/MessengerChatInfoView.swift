import SwiftUI

struct MessengerChatInfoView: View {
    let chat: MessengerChat?
    let onChangePermission: (MessengerChatPermission) -> Void
    let onToggleArchive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if let chat {
                Text(chat.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Picker("Schreibrechte", selection: Binding(
                    get: { chat.writePermission },
                    set: onChangePermission
                )) {
                    ForEach(MessengerChatPermission.allCases) { permission in
                        Text(permissionLabel(permission)).tag(permission)
                    }
                }
                .pickerStyle(.menu)

                if let until = chat.temporaryUntil {
                    Text("Temporär bis \(DateFormatters.shortDate.string(from: until))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Button(chat.archived ? "Wiederherstellen" : "Archivieren") {
                    onToggleArchive()
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Divider()

                Text("Teilnehmer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(chat.participants) { participant in
                            HStack {
                                Text(participant.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Text(participant.role == .trainer ? "Trainer" : "Spieler")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
            } else {
                Spacer()
                Text("Kein Chat ausgewählt")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            }
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

    private func permissionLabel(_ permission: MessengerChatPermission) -> String {
        switch permission {
        case .trainerOnly:
            return "Nur Trainer"
        case .allMembers:
            return "Alle"
        case .custom:
            return "Benutzerdefiniert"
        }
    }
}

