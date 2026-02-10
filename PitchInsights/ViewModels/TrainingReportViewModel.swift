import Foundation
import Combine

@MainActor
final class TrainingReportViewModel: ObservableObject {
    @Published var summary = ""
    @Published var groupFeedbackByGroup: [UUID: String] = [:]
    @Published var playerNotesByPlayer: [UUID: String] = [:]
    @Published var statusMessage: String?
    @Published var isGenerating = false

    func prepare(planID: UUID, store: AppDataStore) {
        guard let report = store.trainingReport(for: planID) else {
            if summary.isEmpty {
                summary = ""
            }
            return
        }

        summary = report.summary
        groupFeedbackByGroup = Dictionary(uniqueKeysWithValues: report.groupFeedback.map { ($0.groupID, $0.feedback) })
        playerNotesByPlayer = Dictionary(uniqueKeysWithValues: report.playerNotes.map { ($0.playerID, $0.note) })
    }

    func generate(planID: UUID, store: AppDataStore, currentUserID: String) async {
        let groupFeedback = store.groups(for: planID).map { group in
            TrainingGroupFeedback(
                groupID: group.id,
                trainerUserID: currentUserID,
                feedback: groupFeedbackByGroup[group.id] ?? ""
            )
        }

        let playerNotes = store.players
            .compactMap { player -> TrainingPlayerNote? in
                guard let note = playerNotesByPlayer[player.id], !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return TrainingPlayerNote(playerID: player.id, note: note)
            }

        isGenerating = true
        defer { isGenerating = false }

        do {
            _ = try await store.generateAndSaveTrainingReport(
                planID: planID,
                summary: summary,
                groupFeedback: groupFeedback,
                playerNotes: playerNotes
            )
            statusMessage = "Bericht gespeichert"
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
