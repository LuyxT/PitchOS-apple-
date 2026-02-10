import Foundation
import Combine

@MainActor
final class TrainingGroupViewModel: ObservableObject {
    @Published var selectedGroupID: UUID?
    @Published var groupName = ""
    @Published var groupGoal = ""
    @Published var headCoachUserID = "trainer.main"
    @Published var assistantCoachUserID = ""
    @Published var selectedPlayerIDs: Set<UUID> = []

    @Published var briefingGoal = ""
    @Published var briefingCoachingPoints = ""
    @Published var briefingFocusPoints = ""
    @Published var briefingCommonMistakes = ""
    @Published var briefingIntensity: TrainingIntensity = .medium

    @Published var statusMessage: String?

    func load(planID: UUID, store: AppDataStore) {
        let groups = store.groups(for: planID)
        if selectedGroupID == nil || !groups.contains(where: { $0.id == selectedGroupID }) {
            selectedGroupID = groups.first?.id
        }

        guard let selectedGroupID,
              let group = groups.first(where: { $0.id == selectedGroupID }) else {
            clearDraft()
            return
        }

        groupName = group.name
        groupGoal = group.goal
        headCoachUserID = group.headCoachUserID
        assistantCoachUserID = group.assistantCoachUserID ?? ""
        selectedPlayerIDs = Set(group.playerIDs)

        if let briefing = store.trainingBriefingsByGroup[selectedGroupID] {
            briefingGoal = briefing.goal
            briefingCoachingPoints = briefing.coachingPoints
            briefingFocusPoints = briefing.focusPoints
            briefingCommonMistakes = briefing.commonMistakes
            briefingIntensity = briefing.targetIntensity
        } else {
            briefingGoal = group.goal
            briefingCoachingPoints = ""
            briefingFocusPoints = ""
            briefingCommonMistakes = ""
            briefingIntensity = .medium
        }
    }

    func createOrUpdateGroup(planID: UUID, store: AppDataStore) async {
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            statusMessage = "Gruppenname fehlt"
            return
        }

        do {
            let group = try await store.createOrUpdateGroup(
                planID: planID,
                groupID: selectedGroupID,
                name: trimmedName,
                goal: groupGoal,
                playerIDs: Array(selectedPlayerIDs).sorted { lhs, rhs in
                    let leftName = store.players.first(where: { $0.id == lhs })?.name ?? ""
                    let rightName = store.players.first(where: { $0.id == rhs })?.name ?? ""
                    return leftName < rightName
                },
                headCoachUserID: headCoachUserID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "trainer.main" : headCoachUserID,
                assistantCoachUserID: assistantCoachUserID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : assistantCoachUserID
            )
            selectedGroupID = group.id
            load(planID: planID, store: store)
            statusMessage = "Gruppe gespeichert"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func saveBriefing(planID: UUID, store: AppDataStore) async {
        guard let selectedGroupID else {
            statusMessage = "Keine Gruppe ausgewählt"
            return
        }

        let briefing = TrainingGroupBriefing(
            backendID: store.trainingBriefingsByGroup[selectedGroupID]?.backendID,
            groupID: selectedGroupID,
            goal: briefingGoal,
            coachingPoints: briefingCoachingPoints,
            focusPoints: briefingFocusPoints,
            commonMistakes: briefingCommonMistakes,
            targetIntensity: briefingIntensity
        )

        do {
            _ = try await store.saveGroupBriefing(groupID: selectedGroupID, briefing: briefing)
            statusMessage = "Briefing gespeichert"
            load(planID: planID, store: store)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func togglePlayer(_ playerID: UUID) {
        if selectedPlayerIDs.contains(playerID) {
            selectedPlayerIDs.remove(playerID)
        } else {
            selectedPlayerIDs.insert(playerID)
        }
    }

    func visibleGroups(planID: UUID, store: AppDataStore, assignedCoachID: String?) -> [TrainingGroup] {
        let all = store.groups(for: planID)
        guard let assignedCoachID, !assignedCoachID.isEmpty else {
            return all
        }
        let filtered = all.filter {
            $0.headCoachUserID == assignedCoachID || $0.assistantCoachUserID == assignedCoachID
        }
        return filtered.isEmpty ? all : filtered
    }

    private func clearDraft() {
        groupName = ""
        groupGoal = ""
        headCoachUserID = "trainer.main"
        assistantCoachUserID = ""
        selectedPlayerIDs = []
        briefingGoal = ""
        briefingCoachingPoints = ""
        briefingFocusPoints = ""
        briefingCommonMistakes = ""
        briefingIntensity = .medium
    }
}
