import SwiftUI

struct MessengerMessageRow: View {
    let message: MessengerMessage
    let onOpenClip: (MessengerClipReference) -> Void
    let onRetry: (MessengerMessage) -> Void
    let onDelete: (MessengerMessage) -> Void

    var body: some View {
        HStack {
            if message.isMine { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(message.senderName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(DateFormatters.dayTime.string(from: message.createdAt))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer(minLength: 0)
                    Text(statusText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(statusColor)
                }

                if let context = message.contextLabel, !context.isEmpty {
                    Text(context)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                switch message.type {
                case .text:
                    Text(message.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .textSelection(.enabled)
                case .image, .video:
                    mediaBody
                case .analysisClipReference:
                    clipBody
                }

                if !message.readBy.isEmpty {
                    Text("Gelesen: \(message.readBy.map(\.userName).joined(separator: ", "))")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(message.isMine ? AppTheme.primary.opacity(0.12) : AppTheme.surfaceAlt.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .contextMenu {
                if message.status == .failed {
                    Button("Erneut senden") {
                        onRetry(message)
                    }
                }
                Button("Löschen", role: .destructive) {
                    onDelete(message)
                }
            }

            if !message.isMine { Spacer(minLength: 40) }
        }
        .contentShape(Rectangle())
    }

    private var mediaBody: some View {
        HStack(spacing: 8) {
            Image(systemName: message.type == .image ? "photo" : "video")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(message.attachment?.filename ?? "Medien")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(message.attachment?.mimeType ?? "")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
    }

    private var clipBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.clipReference?.clipName ?? "Analyse-Clip")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if let clip = message.clipReference {
                Text("\(format(clip.timeStart)) - \(format(clip.timeEnd))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()

                Button("Clip öffnen") {
                    onOpenClip(clip)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
    }

    private var statusText: String {
        switch message.status {
        case .queued:
            return "Wartend"
        case .uploading:
            return "Upload"
        case .sent:
            return "Gesendet"
        case .delivered:
            return "Zugestellt"
        case .read:
            return "Gelesen"
        case .failed:
            return "Fehler"
        }
    }

    private var statusColor: Color {
        switch message.status {
        case .failed:
            return .red
        case .queued, .uploading:
            return .orange
        default:
            return AppTheme.textSecondary
        }
    }

    private func format(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

