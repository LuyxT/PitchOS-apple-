import Foundation
import Combine

@MainActor
final class TrainingPlanEditorViewModel: ObservableObject {
    @Published var selectedPhaseID: UUID?
    @Published var newPhaseType: TrainingPhaseType = .main
    @Published var newExerciseName = ""
    @Published var templateSearchText = ""
    @Published var statusMessage: String?

    func phases(for planID: UUID, store: AppDataStore) -> [TrainingPhase] {
        store.phases(for: planID)
    }

    func exercises(for phaseID: UUID, store: AppDataStore) -> [TrainingExercise] {
        store.exercises(for: phaseID)
    }

    func ensureSelection(planID: UUID, store: AppDataStore) {
        let allPhases = phases(for: planID, store: store)
        if selectedPhaseID == nil || !allPhases.contains(where: { $0.id == selectedPhaseID }) {
            selectedPhaseID = allPhases.first?.id
        }
    }

    func addPhase(planID: UUID, store: AppDataStore) async {
        do {
            let created = try await store.addPhase(planID: planID, type: newPhaseType)
            selectedPhaseID = created.id
            statusMessage = "Phase hinzugefügt"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func duplicatePhase(planID: UUID, phaseID: UUID, store: AppDataStore) async {
        do {
            let duplicated = try await store.duplicatePhase(planID: planID, phaseID: phaseID)
            selectedPhaseID = duplicated.id
            statusMessage = "Phase kopiert"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func deletePhase(planID: UUID, phaseID: UUID, store: AppDataStore) async {
        do {
            try await store.deletePhase(planID: planID, phaseID: phaseID)
            ensureSelection(planID: planID, store: store)
            statusMessage = "Phase gelöscht"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func movePhase(planID: UUID, from sourceIndex: Int, to destinationIndex: Int, store: AppDataStore) async {
        guard sourceIndex != destinationIndex else { return }
        do {
            let source = IndexSet(integer: sourceIndex)
            let destination = destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
            try await store.movePhase(planID: planID, source: source, destination: destination)
            statusMessage = "Phase verschoben"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func savePhase(planID: UUID, phase: TrainingPhase, store: AppDataStore) async {
        do {
            _ = try await store.updatePhase(planID: planID, phase: phase)
            statusMessage = "Phase gespeichert"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func addExercise(to phaseID: UUID, store: AppDataStore) async {
        let name = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            statusMessage = "Übungsname fehlt"
            return
        }

        do {
            _ = try await store.addExercise(
                phaseID: phaseID,
                name: name,
                description: "",
                durationMinutes: 12,
                intensity: .medium,
                requiredPlayers: 8
            )
            newExerciseName = ""
            statusMessage = "Übung hinzugefügt"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func duplicateExercise(phaseID: UUID, exerciseID: UUID, store: AppDataStore) async {
        do {
            _ = try await store.duplicateExercise(phaseID: phaseID, exerciseID: exerciseID)
            statusMessage = "Übung kopiert"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func deleteExercise(phaseID: UUID, exerciseID: UUID, store: AppDataStore) async {
        do {
            try await store.deleteExercise(phaseID: phaseID, exerciseID: exerciseID)
            statusMessage = "Übung gelöscht"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func saveExercise(_ exercise: TrainingExercise, store: AppDataStore) async {
        do {
            _ = try await store.updateExercise(exercise)
            statusMessage = "Übung gespeichert"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func moveExercise(phaseID: UUID, from sourceIndex: Int, to destinationIndex: Int, store: AppDataStore) async {
        guard sourceIndex != destinationIndex else { return }
        do {
            let source = IndexSet(integer: sourceIndex)
            let destination = destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
            try await store.moveExercise(phaseID: phaseID, source: source, destination: destination)
            statusMessage = "Übung verschoben"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func saveExerciseAsTemplate(exerciseID: UUID, customName: String?, store: AppDataStore) async {
        do {
            _ = try await store.saveExerciseAsTemplate(exerciseID: exerciseID, name: customName)
            statusMessage = "Als Vorlage gespeichert"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func addTemplate(to phaseID: UUID, templateID: UUID, store: AppDataStore) async {
        do {
            _ = try await store.instantiateExerciseTemplate(templateID: templateID, phaseID: phaseID)
            statusMessage = "Vorlage übernommen"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func templates(in store: AppDataStore) -> [TrainingExerciseTemplate] {
        let base = store.trainingTemplates
        let query = templateSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return base.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return base
            .filter {
                $0.name.localizedCaseInsensitiveContains(query) ||
                $0.baseDescription.localizedCaseInsensitiveContains(query)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
