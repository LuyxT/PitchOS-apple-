import Foundation
import Combine

@MainActor
final class TrainingLiveViewModel: ObservableObject {
    @Published var selectedPhaseID: UUID?
    @Published var actualMinutesByExercise: [UUID: Int] = [:]
    @Published var skippedExercises: Set<UUID> = []
    @Published var deviationNote = ""
    @Published var statusMessage: String?

    func prepare(planID: UUID, store: AppDataStore) {
        if selectedPhaseID == nil {
            selectedPhaseID = store.phases(for: planID).first?.id
        }

        for phase in store.phases(for: planID) {
            for exercise in store.exercises(for: phase.id) {
                actualMinutesByExercise[exercise.id] = exercise.actualDurationMinutes ?? exercise.durationMinutes
                if exercise.isSkippedLive {
                    skippedExercises.insert(exercise.id)
                }
            }
        }
    }

    func start(planID: UUID, store: AppDataStore) async {
        do {
            try await store.startLiveMode(planID: planID)
            statusMessage = "Live-Modus aktiv"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func togglePhaseCompletion(planID: UUID, phase: TrainingPhase, store: AppDataStore) async {
        do {
            try await store.completePhaseLive(planID: planID, phaseID: phase.id, completed: !phase.isCompletedLive)
            statusMessage = "Phase aktualisiert"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func setExerciseDuration(planID: UUID, exercise: TrainingExercise, minutes: Int, store: AppDataStore) async {
        let safeMinutes = max(1, minutes)
        actualMinutesByExercise[exercise.id] = safeMinutes
        do {
            try await store.adjustExerciseLive(
                planID: planID,
                exerciseID: exercise.id,
                actualDurationMinutes: safeMinutes,
                skipped: skippedExercises.contains(exercise.id)
            )
            statusMessage = "Ist-Dauer gespeichert"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func toggleExerciseSkip(planID: UUID, exercise: TrainingExercise, store: AppDataStore) async {
        if skippedExercises.contains(exercise.id) {
            skippedExercises.remove(exercise.id)
        } else {
            skippedExercises.insert(exercise.id)
        }

        do {
            try await store.adjustExerciseLive(
                planID: planID,
                exerciseID: exercise.id,
                actualDurationMinutes: actualMinutesByExercise[exercise.id] ?? exercise.durationMinutes,
                skipped: skippedExercises.contains(exercise.id)
            )
            statusMessage = skippedExercises.contains(exercise.id) ? "Übung übersprungen" : "Übung wieder aktiv"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func extendExercise(planID: UUID, exercise: TrainingExercise, delta: Int, store: AppDataStore) async {
        let base = actualMinutesByExercise[exercise.id] ?? exercise.durationMinutes
        let next = max(1, base + delta)
        actualMinutesByExercise[exercise.id] = next

        do {
            try await store.adjustExerciseLive(
                planID: planID,
                exerciseID: exercise.id,
                actualDurationMinutes: next,
                skipped: skippedExercises.contains(exercise.id)
            )
            _ = try await store.recordLiveDeviation(
                planID: planID,
                phaseID: store.phases(for: planID).first(where: { phase in
                    store.exercises(for: phase.id).contains(where: { $0.id == exercise.id })
                })?.id,
                exerciseID: exercise.id,
                kind: delta >= 0 ? .extended : .timeAdjusted,
                plannedValue: "\(exercise.durationMinutes) min",
                actualValue: "\(next) min",
                note: deviationNote
            )
            statusMessage = "Abweichung protokolliert"
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
