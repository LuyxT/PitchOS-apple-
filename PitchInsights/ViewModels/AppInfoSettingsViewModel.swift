import Foundation
import Combine

@MainActor
final class AppInfoSettingsViewModel: ObservableObject {
    @Published var state: AppInfoState = .default
    @Published var statusMessage: String?

    private let service = SettingsService()

    func load(store: AppDataStore) {
        state = store.settingsAppInfo
    }

    func refresh(store: AppDataStore) async {
        await service.refreshAppInfo(store: store)
        state = store.settingsAppInfo
        statusMessage = "App-Information aktualisiert."
    }
}
