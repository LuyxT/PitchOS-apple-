import Foundation
import Combine

@MainActor
final class AuditLogViewModel: ObservableObject {
    @Published var filter = AdminAuditFilter()
    @Published var isLoading = false
    @Published var statusMessage: String?

    func apply(store: AppDataStore) async {
        isLoading = true
        defer { isLoading = false }
        await store.loadAdminAuditEntries(filter: filter)
        if case .failed(let message) = store.adminConnectionState {
            statusMessage = message
        } else {
            statusMessage = nil
        }
    }
}
