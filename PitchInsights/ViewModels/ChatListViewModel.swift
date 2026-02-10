import Foundation
import Combine

@MainActor
final class ChatListViewModel: ObservableObject {
    @Published var selectedChatID: UUID?
    @Published var searchQuery = ""
    @Published var includeArchived = false
    @Published var isLoading = false
    @Published var nextCursor: String?

    func orderedChats(from chats: [MessengerChat]) -> [MessengerChat] {
        chats.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned {
                return lhs.pinned && !rhs.pinned
            }
            return (lhs.lastMessageAt ?? lhs.updatedAt) > (rhs.lastMessageAt ?? rhs.updatedAt)
        }
    }

    func ensureValidSelection(chats: [MessengerChat]) {
        let ids = Set(chats.map(\.id))
        if let selectedChatID, ids.contains(selectedChatID) {
            return
        }
        selectedChatID = chats.first?.id
    }
}
