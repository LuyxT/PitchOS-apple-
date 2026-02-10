import Foundation

enum MessengerOutboxStoreError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Outbox nicht verfügbar."
        }
    }
}

final class MessengerOutboxStore {
    private var cache: [MessengerOutboxItem] = []

    func loadItems() throws -> [MessengerOutboxItem] {
        cache
    }

    func saveItems(_ items: [MessengerOutboxItem]) throws {
        cache = items
    }
}
