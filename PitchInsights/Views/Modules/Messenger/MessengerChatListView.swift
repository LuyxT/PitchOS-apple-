import SwiftUI

struct MessengerChatListView: View {
    let chats: [MessengerChat]
    @Binding var selectedChatID: UUID?
    @Binding var searchQuery: String
    @Binding var includeArchived: Bool
    let hasMore: Bool
    let onLoadMore: () -> Void
    let onRefresh: () -> Void
    let onTogglePin: (MessengerChat) -> Void
    let onToggleMute: (MessengerChat) -> Void
    let onToggleArchive: (MessengerChat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Messenger")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Toggle("Archiv", isOn: $includeArchived)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            TextField("Suche", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(AppTheme.textPrimary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(chats) { chat in
                        row(chat)
                    }
                    if hasMore {
                        Button("Mehr laden") {
                            onLoadMore()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                    }
                }
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
        .toolbar {
            Button("Aktualisieren") {
                Haptics.trigger(.soft)
                onRefresh()
            }
        }
    }

    private func row(_ chat: MessengerChat) -> some View {
        let selected = selectedChatID == chat.id

        return HStack(spacing: 8) {
            Image(systemName: chat.type == .group ? "person.3" : "person.2")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(chat.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    if chat.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    if chat.muted {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer(minLength: 0)
                    if let ts = chat.lastMessageAt {
                        Text(DateFormatters.dayTime.string(from: ts))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                Text(chat.lastMessagePreview.isEmpty ? "Keine Nachricht" : chat.lastMessagePreview)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            if chat.unreadCount > 0 {
                Text("\(chat.unreadCount)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(AppTheme.primary.opacity(0.22)))
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(selected ? AppTheme.primary.opacity(0.15) : AppTheme.surfaceAlt.opacity(0.45))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.trigger(.light)
            selectedChatID = chat.id
        }
        .interactiveSurface(hoverScale: 1.01, pressScale: 0.99, hoverShadowOpacity: 0.1, feedback: .light)
        .contextMenu {
            Button(chat.pinned ? "Loslösen" : "Anheften") {
                Haptics.trigger(.soft)
                onTogglePin(chat)
            }
            Button(chat.muted ? "Stumm aus" : "Stummschalten") {
                Haptics.trigger(.soft)
                onToggleMute(chat)
            }
            Button(chat.archived ? "Wiederherstellen" : "Archivieren") {
                Haptics.trigger(.soft)
                onToggleArchive(chat)
            }
        }
    }
}

