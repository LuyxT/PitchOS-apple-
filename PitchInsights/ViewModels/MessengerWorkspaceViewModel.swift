import Foundation
import Combine

@MainActor
final class MessengerWorkspaceViewModel: ObservableObject {
    @Published var composeGroupName = ""
    @Published var groupWritePermission: MessengerChatPermission = .allMembers
    @Published var selectedParticipantUserIDs: Set<String> = []
    @Published var temporaryGroupEndDate: Date?
    @Published var isCreatingGroup = false
    @Published var isBootstrapping = false
    @Published var errorMessage: String?

    private var searchTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0

    func bootstrap(store: AppDataStore) async {
        isBootstrapping = true
        defer { isBootstrapping = false }
        await store.bootstrapMessenger()
    }

    func scheduleSearch(
        query: String,
        includeArchived: Bool,
        store: AppDataStore
    ) {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await store.searchMessenger(query: query, includeArchived: includeArchived)
            await MainActor.run {
                self?.errorMessage = nil
            }
        }
    }

    func createGroup(store: AppDataStore) async {
        let name = composeGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Gruppenname fehlt."
            return
        }
        guard !selectedParticipantUserIDs.isEmpty else {
            errorMessage = "Teilnehmer auswählen."
            return
        }

        isCreatingGroup = true
        defer { isCreatingGroup = false }
        do {
            try await store.createGroupChat(
                title: name,
                participantUserIDs: Array(selectedParticipantUserIDs),
                writePermission: groupWritePermission,
                temporaryUntil: temporaryGroupEndDate
            )
            composeGroupName = ""
            selectedParticipantUserIDs.removeAll()
            temporaryGroupEndDate = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func scheduleRealtimeReconnect(store: AppDataStore) {
        guard AppConfiguration.messagingEnabled else { return }
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            let delay = self.nextReconnectDelay()
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await store.reconnectMessengerRealtimeIfNeeded()
        }
    }

    func resetReconnectBackoff() {
        reconnectAttempt = 0
        reconnectTask?.cancel()
    }

    private func nextReconnectDelay() -> Double {
        let base = min(pow(2.0, Double(reconnectAttempt)), 30)
        reconnectAttempt += 1
        let jitter = Double.random(in: 0..<0.45)
        return min(30, base + jitter)
    }
}
