import Foundation
import Combine

@MainActor
final class AdminWorkspaceViewModel: ObservableObject {
    @Published var selectedSection: AdminSection = .dashboard
    @Published var isBootstrapping = false
    @Published var statusMessage: String?
    @Published var quickSearch: String = ""
    @Published var showOnlyActiveSeason = true

    func bootstrap(store: AppDataStore) async {
        isBootstrapping = true
        defer { isBootstrapping = false }
        await store.bootstrapAdministration()
        if case .failed(let message) = store.adminConnectionState {
            statusMessage = message
        } else {
            statusMessage = nil
        }
    }
}
