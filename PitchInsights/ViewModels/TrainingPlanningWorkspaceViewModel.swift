import Foundation
import SwiftUI
import Combine

@MainActor
final class TrainingPlanningWorkspaceViewModel: ObservableObject {
    enum Section: String, CaseIterable, Identifiable {
        case planung = "Planung"
        case live = "Live"
        case bericht = "Bericht"

        var id: String { rawValue }
    }

    @Published var selectedSection: Section = .planung
    @Published var selectedPlanID: UUID?
    @Published var isBootstrapping = false
    @Published var isSaving = false
    @Published var statusMessage: String?
    @Published var draftTitle = ""
    @Published var draftDate = Date()
    @Published var draftLocation = ""
    @Published var draftMainGoal = ""
    @Published var draftSecondaryGoals = ""

    func bootstrapIfNeeded(store: AppDataStore) async {
        guard !isBootstrapping else { return }
        if store.trainingPlans.isEmpty {
            await bootstrap(store: store)
            return
        }
        if selectedPlanID == nil {
            selectedPlanID = store.activeTrainingPlanID ?? store.trainingPlans.first?.id
        }
        syncDraft(with: activePlan(in: store))
    }

    func bootstrap(store: AppDataStore) async {
        isBootstrapping = true
        defer { isBootstrapping = false }
        await store.bootstrapTrainingsplanung()
        if selectedPlanID == nil {
            selectedPlanID = store.activeTrainingPlanID ?? store.trainingPlans.first?.id
        }
        syncDraft(with: activePlan(in: store))
    }

    func activePlan(in store: AppDataStore) -> TrainingPlan? {
        let all = store.sortedTrainingPlans()
        guard let selectedPlanID else { return all.first }
        return all.first(where: { $0.id == selectedPlanID }) ?? all.first
    }

    func selectPlan(_ planID: UUID?, store: AppDataStore) {
        selectedPlanID = planID
        store.activeTrainingPlanID = planID
        syncDraft(with: activePlan(in: store))
    }

    func syncDraft(with plan: TrainingPlan?) {
        guard let plan else {
            draftTitle = ""
            draftDate = Date()
            draftLocation = ""
            draftMainGoal = ""
            draftSecondaryGoals = ""
            return
        }
        draftTitle = plan.title
        draftDate = plan.date
        draftLocation = plan.location
        draftMainGoal = plan.mainGoal
        draftSecondaryGoals = plan.secondaryGoals.joined(separator: ", ")
    }

    func createPlan(store: AppDataStore) async {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            statusMessage = "Bitte Titel eingeben."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let draft = TrainingPlanDraft(
                title: title,
                date: draftDate,
                location: draftLocation,
                mainGoal: draftMainGoal,
                secondaryGoals: parseSecondaryGoals(draftSecondaryGoals),
                linkedMatchID: nil
            )
            let plan = try await store.createTrainingPlan(draft)
            selectedPlanID = plan.id
            store.activeTrainingPlanID = plan.id
            syncDraft(with: plan)
            statusMessage = "Training erstellt"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func savePlan(store: AppDataStore) async {
        guard var plan = activePlan(in: store) else {
            statusMessage = "Kein Training ausgewählt."
            return
        }

        plan.title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.date = draftDate
        plan.location = draftLocation
        plan.mainGoal = draftMainGoal
        plan.secondaryGoals = parseSecondaryGoals(draftSecondaryGoals)
        plan.updatedAt = Date()

        guard !plan.title.isEmpty else {
            statusMessage = "Bitte Titel eingeben."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let updated = try await store.updateTrainingPlan(plan)
            selectedPlanID = updated.id
            syncDraft(with: updated)
            statusMessage = "Training gespeichert"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func deleteActivePlan(store: AppDataStore) async {
        guard let selectedPlanID else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await store.deleteTrainingPlan(planID: selectedPlanID)
            let nextPlan = store.sortedTrainingPlans().first
            self.selectedPlanID = nextPlan?.id
            store.activeTrainingPlanID = nextPlan?.id
            syncDraft(with: nextPlan)
            statusMessage = "Training gelöscht"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func duplicateAsTemplate(store: AppDataStore) async {
        guard let plan = activePlan(in: store) else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            _ = try await store.duplicatePlanAsTemplate(planID: plan.id, templateName: "\(plan.title) Vorlage")
            statusMessage = "Als Vorlage gespeichert"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func linkToCalendar(store: AppDataStore, includeGoal: Bool) async {
        guard let plan = activePlan(in: store) else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let visibility = TrainingCalendarVisibility(playersViewLevel: includeGoal ? .basicPlusGoalDuration : .basic)
            _ = try await store.linkTrainingToCalendar(planID: plan.id, visibility: visibility)
            statusMessage = "In Kalender übernommen"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func startLiveMode(store: AppDataStore) async {
        guard let plan = activePlan(in: store) else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await store.startLiveMode(planID: plan.id)
            selectedSection = .live
            statusMessage = "Live-Modus gestartet"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func parseSecondaryGoals(_ input: String) -> [String] {
        input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
