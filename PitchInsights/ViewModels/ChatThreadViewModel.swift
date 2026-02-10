import Foundation
import Combine

@MainActor
final class ChatThreadViewModel: ObservableObject {
    @Published var isLoadingMessages = false
    @Published var isLoadingOlder = false
    @Published var nextCursorByChat: [UUID: String] = [:]

    func resetPagination(for chatID: UUID) {
        nextCursorByChat[chatID] = nil
    }

    func setNextCursor(_ cursor: String?, for chatID: UUID) {
        nextCursorByChat[chatID] = cursor
    }

    func nextCursor(for chatID: UUID) -> String? {
        nextCursorByChat[chatID]
    }

    func hasMore(for chatID: UUID) -> Bool {
        nextCursorByChat[chatID] != nil
    }
}
