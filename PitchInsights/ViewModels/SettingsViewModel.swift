import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedSection: SettingsSection = .personalProfile
    @Published var isBootstrapping = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let service = SettingsService()

    func bootstrap(store: AppDataStore) async {
        isBootstrapping = true
        defer { isBootstrapping = false }

        await service.bootstrap(store: store)
        if case .failed(let error) = store.settingsConnectionState {
            errorMessage = error
        } else {
            statusMessage = "Einstellungen geladen."
            errorMessage = nil
        }
    }
}
