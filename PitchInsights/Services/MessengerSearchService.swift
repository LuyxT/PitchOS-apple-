import Foundation

struct MessengerSearchService {
    func localSearch(
        query: String,
        includeArchived: Bool,
        chats: [MessengerChat],
        messagesByChat: [UUID: [MessengerMessage]],
        analysisClips: [AnalysisClip],
        analysisMarkers: [AnalysisMarker]
    ) -> [MessengerSearchResult] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }

        var results: [MessengerSearchResult] = []

        for chat in chats where includeArchived || !chat.archived {
            if chat.title.lowercased().contains(needle) {
                results.append(
                    MessengerSearchResult(
                        id: UUID(),
                        type: .chat,
                        chatID: chat.id,
                        messageID: nil,
                        title: chat.title,
                        subtitle: "Chat",
                        occurredAt: chat.updatedAt
                    )
                )
            }
        }

        for (chatID, messages) in messagesByChat {
            for message in messages where message.text.lowercased().contains(needle) || (message.contextLabel?.lowercased().contains(needle) == true) {
                results.append(
                    MessengerSearchResult(
                        id: UUID(),
                        type: .message,
                        chatID: chatID,
                        messageID: message.id,
                        title: message.senderName,
                        subtitle: message.text.isEmpty ? (message.contextLabel ?? "Nachricht") : message.text,
                        occurredAt: message.createdAt
                    )
                )
            }
        }

        for clip in analysisClips where clip.name.lowercased().contains(needle) {
            results.append(
                MessengerSearchResult(
                    id: UUID(),
                    type: .analysisClip,
                    chatID: nil,
                    messageID: nil,
                    title: clip.name,
                    subtitle: "Analyse-Clip",
                    occurredAt: clip.updatedAt
                )
            )
        }

        for marker in analysisMarkers where marker.comment.lowercased().contains(needle) {
            results.append(
                MessengerSearchResult(
                    id: UUID(),
                    type: .analysisMarker,
                    chatID: nil,
                    messageID: nil,
                    title: marker.comment,
                    subtitle: "Marker \(formatTime(marker.timeSeconds))",
                    occurredAt: marker.updatedAt
                )
            )
        }

        return results.sorted { lhs, rhs in
            (lhs.occurredAt ?? .distantPast) > (rhs.occurredAt ?? .distantPast)
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

