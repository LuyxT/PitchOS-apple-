import Foundation
import Combine

@MainActor
final class MessageComposerViewModel: ObservableObject {
    @Published var text = ""
    @Published var contextLabel = ""
    @Published var selectedClipID: UUID?
    @Published var selectedCloudFileID: UUID?
    @Published var selectedCloudFileName: String = ""
    @Published var pendingAttachmentURL: URL?
    @Published var pendingAttachmentName: String = ""
    @Published var isSending = false

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedContext: String {
        contextLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSend: Bool {
        !trimmedText.isEmpty || selectedClipID != nil || pendingAttachmentURL != nil || selectedCloudFileID != nil
    }

    func clearAfterSend() {
        text = ""
        contextLabel = ""
        selectedClipID = nil
        selectedCloudFileID = nil
        selectedCloudFileName = ""
        pendingAttachmentURL = nil
        pendingAttachmentName = ""
    }
}
