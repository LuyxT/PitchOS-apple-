import Foundation
import Combine
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

@MainActor
final class FeedbackSettingsViewModel: ObservableObject {
    @Published var draft: FeedbackDraft = .empty
    @Published var isSubmitting = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let service = SettingsService()
    private let validator = SettingsValidationService()

    func submit(store: AppDataStore, activeModuleID: String) async {
        if let validationError = validator.validateFeedbackMessage(draft.message) {
            errorMessage = validationError
            statusMessage = nil
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let appInfo = store.settingsAppInfo
        let payload = SettingsFeedbackPayload(
            category: draft.category.rawValue,
            message: draft.message,
            screenshotPath: draft.screenshotPath,
            appVersion: appInfo.version,
            buildNumber: appInfo.buildNumber,
            deviceModel: deviceName,
            platform: platformName,
            activeModuleID: activeModuleID
        )

        do {
            try await service.submitFeedback(payload, store: store)
            draft = .empty
            statusMessage = "Feedback gesendet."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    private var platformName: String {
        #if os(macOS)
        return "macOS"
        #elseif os(iOS)
        return "iOS"
        #else
        return "Unknown"
        #endif
    }

    private var deviceName: String {
        #if os(macOS)
        return Host.current().localizedName ?? "Mac"
        #elseif os(iOS)
        return UIDevice.current.model
        #else
        return "Device"
        #endif
    }
}
