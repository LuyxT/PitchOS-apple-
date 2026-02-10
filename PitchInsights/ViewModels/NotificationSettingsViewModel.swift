import Foundation
import Combine

@MainActor
final class NotificationSettingsViewModel: ObservableObject {
    @Published var draft: NotificationSettingsState = .default
    @Published var isSaving = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let service = SettingsService()

    func load(store: AppDataStore) {
        draft = store.settingsNotifications
    }

    func bindingForModule(_ module: NotificationModuleKey) -> ModuleNotificationSetting? {
        draft.modules.first(where: { $0.id == module })
    }

    func setPush(_ value: Bool, module: NotificationModuleKey) {
        guard let index = draft.modules.firstIndex(where: { $0.id == module }) else { return }
        draft.modules[index].channels.push = value
    }

    func setInApp(_ value: Bool, module: NotificationModuleKey) {
        guard let index = draft.modules.firstIndex(where: { $0.id == module }) else { return }
        draft.modules[index].channels.inApp = value
    }

    func setEmail(_ value: Bool, module: NotificationModuleKey) {
        guard let index = draft.modules.firstIndex(where: { $0.id == module }) else { return }
        draft.modules[index].channels.email = value
    }

    func save(store: AppDataStore) async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await service.saveNotifications(draft, store: store)
            statusMessage = "Benachrichtigungen gespeichert."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }
}
