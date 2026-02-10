import SwiftUI

struct MessengerThreadView: View {
    let chat: MessengerChat?
    let messages: [MessengerMessage]
    let hasMore: Bool
    let onLoadOlder: () -> Void
    let onOpenClip: (MessengerClipReference) -> Void
    let onRetryMessage: (MessengerMessage) -> Void
    let onDeleteMessage: (MessengerMessage) -> Void
    let onMarkRead: () -> Void
    let composer: AnyView

    var body: some View {
        VStack(spacing: 10) {
            header

            if chat == nil {
                Spacer()
                Text("Chat auswählen")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if hasMore {
                                Button("Ältere Nachrichten laden") {
                                    Haptics.trigger(.soft)
                                    onLoadOlder()
                                }
                                .buttonStyle(SecondaryActionButtonStyle())
                            }

                            ForEach(messages) { message in
                                MessengerMessageRow(
                                    message: message,
                                    onOpenClip: onOpenClip,
                                    onRetry: onRetryMessage,
                                    onDelete: onDeleteMessage
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: messages.last?.id) { _, newID in
                        guard let newID else { return }
                        withAnimation(AppMotion.settle) {
                            proxy.scrollTo(newID, anchor: .bottom)
                        }
                    }
                    .onAppear {
                        onMarkRead()
                    }
                }

                composer
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

    private var header: some View {
        HStack(spacing: 8) {
            if let chat {
                Text(chat.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                if chat.writePermission == .trainerOnly {
                    Text("Nur Trainer schreiben")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AppTheme.surfaceAlt))
                }
            } else {
                Text("Nachrichten")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Spacer()
        }
    }
}

