import Foundation
import SwiftUI

@MainActor
extension AppDataStore {
    func bootstrapTrainingsplanung() async {
        guard !AppConfiguration.isPlaceholder else {
            trainingConnectionState = .failed("Backend für Trainingsplanung erforderlich.")
            return
        }

        trainingConnectionState = .syncing
        do {
            let plansPage = try await backend.fetchTrainingPlans(
                cursor: nil,
                limit: 80,
                from: nil,
                to: nil,
                coachID: trainingFilterAssignedCoachID
            )
            trainingPlans = plansPage.items.map { mapTrainingPlan(dto: $0) }

            let templates = try await backend.fetchTrainingTemplates(query: nil, cursor: nil, limit: 120)
            trainingTemplates = templates.items.map(mapTrainingTemplate(dto:))

            if activeTrainingPlanID == nil {
                activeTrainingPlanID = trainingPlans.first?.id
            }

            if let activeTrainingPlanID,
               let plan = trainingPlans.first(where: { $0.id == activeTrainingPlanID }),
               let backendID = plan.backendID {
                try await loadTrainingPlanDetails(backendPlanID: backendID)
            }

            trainingConnectionState = .live
        } catch {
            if isConnectivityFailure(error) {
                trainingConnectionState = .failed(error.localizedDescription)
                motionError(error, scope: .trainingsplan, title: "Trainingsplanung offline")
            } else {
                print("[client] bootstrapTrainingsplanung: endpoint not available — \(error.localizedDescription)")
                trainingConnectionState = .live
                motionError(error, scope: .trainingsplan, title: "Trainingsplanung konnte nicht geladen werden")
            }
        }
    }

    func createTrainingPlan(_ draft: TrainingPlanDraft) async throws -> TrainingPlan {
        guard !AppConfiguration.isPlaceholder else {
            throw TrainingStoreError.backendUnavailable
        }
        let trimmed = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TrainingStoreError.invalidTitle
        }

        motionProgress(
            "Training wird erstellt",
            subtitle: trimmed,
            progress: nil,
            scope: .trainingsplan
        )

        do {
            let dto = try await backend.createTrainingPlan(
                CreateTrainingPlanRequest(
                    title: trimmed,
                    date: draft.date,
                    location: draft.location,
                    mainGoal: draft.mainGoal,
                    secondaryGoals: draft.secondaryGoals,
                    linkedMatchID: draft.linkedMatchID
                )
            )

            let localPlan = mapTrainingPlan(dto: dto)
            upsertTrainingPlan(localPlan)

            let defaultPhases = TrainingPhase.defaults(planID: localPlan.id)
            _ = try await savePhases(planID: localPlan.id, phases: defaultPhases)

            activeTrainingPlanID = localPlan.id
            try await loadTrainingPlanDetails(backendPlanID: dto.id)
            upsertTrainingPlanCloudFileReference(localPlan)
            motionClearProgress()
            motionCreate(
                "Training erstellt",
                subtitle: localPlan.title,
                scope: .trainingsplan,
                contextId: localPlan.id.uuidString,
                icon: "figure.soccer"
            )
            return localPlan
        } catch {
            motionClearProgress()
            motionError(error, scope: .trainingsplan, title: "Training konnte nicht erstellt werden")
            throw error
        }
    }

    func updateTrainingPlan(_ plan: TrainingPlan) async throws -> TrainingPlan {
        guard !AppConfiguration.isPlaceholder else {
            throw TrainingStoreError.backendUnavailable
        }
        guard let backendID = plan.backendID else {
            throw AnalysisStoreError.backendIdentifierMissing
        }

        do {
            let dto = try await backend.updateTrainingPlan(
                planID: backendID,
                request: UpdateTrainingPlanRequest(
                    title: plan.title,
                    date: plan.date,
                    location: plan.location,
                    mainGoal: plan.mainGoal,
                    secondaryGoals: plan.secondaryGoals,
                    linkedMatchID: plan.linkedMatchID,
                    status: plan.status.rawValue
                )
            )

            let updated = mapTrainingPlan(dto: dto, fallbackLocalID: plan.id)
            upsertTrainingPlan(updated)
            upsertTrainingPlanCloudFileReference(updated)
            motionUpdate(
                "Training aktualisiert",
                subtitle: updated.title,
                scope: .trainingsplan,
                contextId: updated.id.uuidString,
                icon: "checkmark.seal.fill"
            )
            return updated
        } catch {
            motionError(error, scope: .trainingsplan, title: "Training konnte nicht aktualisiert werden", contextId: plan.id.uuidString)
            throw error
        }
    }

    func deleteTrainingPlan(planID: UUID) async throws {
        guard !AppConfiguration.isPlaceholder else {
            throw TrainingStoreError.backendUnavailable
        }
        guard let plan = trainingPlans.first(where: { $0.id == planID }),
              let backendID = plan.backendID else {
            throw TrainingStoreError.planNotFound
        }

        do {
            _ = try await backend.deleteTrainingPlan(planID: backendID)
        } catch {
            motionError(error, scope: .trainingsplan, title: "Training konnte nicht gelöscht werden", contextId: planID.uuidString)
            throw error
        }

        let phaseIDs = Set((trainingPhasesByPlan[planID] ?? []).map(\.id))
        trainingPlans.removeAll { $0.id == planID }
        trainingPhasesByPlan.removeValue(forKey: planID)
        for key in phaseIDs {
            trainingExercisesByPhase.removeValue(forKey: key)
        }
        trainingGroupsByPlan.removeValue(forKey: planID)
        trainingAvailabilityByPlan.removeValue(forKey: planID)
        trainingDeviationsByPlan.removeValue(forKey: planID)
        trainingReportsByPlan.removeValue(forKey: planID)
        removeTrainingPlanCloudFileReference(planID: planID)

        if activeTrainingPlanID == planID {
            activeTrainingPlanID = trainingPlans.first?.id
        }
        motionDelete(
            "Training gelöscht",
            subtitle: plan.title,
            scope: .trainingsplan,
            contextId: planID.uuidString,
            icon: "trash.circle.fill"
        )
    }

    func addPhase(planID: UUID, type: TrainingPhaseType) async throws -> TrainingPhase {
        guard var phases = trainingPhasesByPlan[planID] else {
            throw TrainingStoreError.planNotFound
        }

        let order = phases.count
        let phase = TrainingPhase(
            planID: planID,
            orderIndex: order,
            type: type,
            title: type.title,
            durationMinutes: type == .main ? 20 : 10,
            goal: "",
            intensity: type == .main ? .high : .medium,
            description: ""
        )
        phases.append(phase)
        let saved = try await savePhases(planID: planID, phases: phases)
        guard let created = saved.last else {
            throw TrainingStoreError.phaseNotFound
        }
        return created
    }

    func movePhase(planID: UUID, source: IndexSet, destination: Int) async throws {
        guard var phases = trainingPhasesByPlan[planID] else {
            throw TrainingStoreError.planNotFound
        }
        phases.move(fromOffsets: source, toOffset: destination)
        for index in phases.indices {
            phases[index].orderIndex = index
        }
        _ = try await savePhases(planID: planID, phases: phases)
    }

    func duplicatePhase(planID: UUID, phaseID: UUID) async throws -> TrainingPhase {
        guard var phases = trainingPhasesByPlan[planID],
              let phaseIndex = phases.firstIndex(where: { $0.id == phaseID }) else {
            throw TrainingStoreError.phaseNotFound
        }

        var duplicate = phases[phaseIndex]
        duplicate.backendID = nil
        duplicate.title = "\(duplicate.title) Kopie"
        duplicate.isCompletedLive = false
        duplicate.orderIndex = phaseIndex + 1
        phases.insert(duplicate, at: phaseIndex + 1)
        for index in phases.indices {
            phases[index].orderIndex = index
        }

        let phaseExerciseIDs = Set([phaseID])
        var newExercisesByPhase = trainingExercisesByPhase
        let sourceExercises = trainingExercisesByPhase[phaseID] ?? []
        let clonedExercises: [TrainingExercise] = sourceExercises.enumerated().map { offset, item in
            var clone = item
            clone.backendID = nil
            clone.phaseID = duplicate.id
            clone.orderIndex = offset
            clone.isSkippedLive = false
            clone.actualDurationMinutes = nil
            return clone
        }
        newExercisesByPhase[duplicate.id] = clonedExercises
        for oldPhase in phaseExerciseIDs {
            if oldPhase != duplicate.id, newExercisesByPhase[oldPhase] == nil {
                newExercisesByPhase[oldPhase] = trainingExercisesByPhase[oldPhase]
            }
        }

        let savedPhases = try await savePhases(planID: planID, phases: phases)
        trainingExercisesByPhase.merge(newExercisesByPhase) { _, new in new }
        try await saveExercises(planID: planID)

        guard let saved = savedPhases.first(where: { $0.orderIndex == phaseIndex + 1 }) else {
            throw TrainingStoreError.phaseNotFound
        }
        return saved
    }

    func addExercise(
        phaseID: UUID,
        name: String,
        description: String = "",
        durationMinutes: Int = 10,
        intensity: TrainingIntensity = .medium,
        requiredPlayers: Int = 6
    ) async throws -> TrainingExercise {
        guard let planID = planID(forPhaseID: phaseID) else {
            throw TrainingStoreError.phaseNotFound
        }

        var exercises = trainingExercisesByPhase[phaseID] ?? []
        let exercise = TrainingExercise(
            phaseID: phaseID,
            orderIndex: exercises.count,
            name: name,
            description: description,
            durationMinutes: durationMinutes,
            intensity: intensity,
            requiredPlayers: requiredPlayers
        )
        exercises.append(exercise)
        trainingExercisesByPhase[phaseID] = exercises

        try await saveExercises(planID: planID)
        return exercises.last ?? exercise
    }

    func moveExercise(phaseID: UUID, source: IndexSet, destination: Int) async throws {
        guard let planID = planID(forPhaseID: phaseID),
              var exercises = trainingExercisesByPhase[phaseID] else {
            throw TrainingStoreError.exerciseNotFound
        }

        exercises.move(fromOffsets: source, toOffset: destination)
        for index in exercises.indices {
            exercises[index].orderIndex = index
        }
        trainingExercisesByPhase[phaseID] = exercises
        try await saveExercises(planID: planID)
    }

    func updatePhase(planID: UUID, phase: TrainingPhase) async throws -> TrainingPhase {
        guard var phases = trainingPhasesByPlan[planID],
              let index = phases.firstIndex(where: { $0.id == phase.id }) else {
            throw TrainingStoreError.phaseNotFound
        }
        phases[index] = phase
        phases[index].orderIndex = index
        let saved = try await savePhases(planID: planID, phases: phases)
        guard let updated = saved.first(where: { $0.id == phase.id }) else {
            throw TrainingStoreError.phaseNotFound
        }
        return updated
    }

    func deletePhase(planID: UUID, phaseID: UUID) async throws {
        guard var phases = trainingPhasesByPlan[planID] else {
            throw TrainingStoreError.planNotFound
        }
        guard phases.contains(where: { $0.id == phaseID }) else {
            throw TrainingStoreError.phaseNotFound
        }

        phases.removeAll { $0.id == phaseID }
        for index in phases.indices {
            phases[index].orderIndex = index
        }
        trainingExercisesByPhase.removeValue(forKey: phaseID)
        _ = try await savePhases(planID: planID, phases: phases)
        try await saveExercises(planID: planID)
    }

    func duplicateExercise(phaseID: UUID, exerciseID: UUID) async throws -> TrainingExercise {
        guard let planID = planID(forPhaseID: phaseID),
              var exercises = trainingExercisesByPhase[phaseID],
              let source = exercises.first(where: { $0.id == exerciseID }) else {
            throw TrainingStoreError.exerciseNotFound
        }

        var clone = source
        clone.backendID = nil
        clone.name = "\(source.name) Kopie"
        clone.isSkippedLive = false
        clone.actualDurationMinutes = nil
        clone.orderIndex = exercises.count
        exercises.append(clone)
        trainingExercisesByPhase[phaseID] = exercises
        try await saveExercises(planID: planID)

        guard let updated = trainingExercisesByPhase[phaseID]?.last else {
            throw TrainingStoreError.exerciseNotFound
        }
        return updated
    }

    func updateExercise(_ exercise: TrainingExercise) async throws -> TrainingExercise {
        guard let phaseID = findExercisePhaseID(exercise.id),
              let planID = planID(forPhaseID: phaseID),
              var exercises = trainingExercisesByPhase[phaseID],
              let index = exercises.firstIndex(where: { $0.id == exercise.id }) else {
            throw TrainingStoreError.exerciseNotFound
        }

        exercises[index] = exercise
        exercises[index].orderIndex = index
        trainingExercisesByPhase[phaseID] = exercises
        try await saveExercises(planID: planID)
        guard let updated = trainingExercisesByPhase[phaseID]?.first(where: { $0.id == exercise.id }) else {
            throw TrainingStoreError.exerciseNotFound
        }
        return updated
    }

    func deleteExercise(phaseID: UUID, exerciseID: UUID) async throws {
        guard let planID = planID(forPhaseID: phaseID),
              var exercises = trainingExercisesByPhase[phaseID] else {
            throw TrainingStoreError.exerciseNotFound
        }
        guard exercises.contains(where: { $0.id == exerciseID }) else {
            throw TrainingStoreError.exerciseNotFound
        }

        exercises.removeAll { $0.id == exerciseID }
        for index in exercises.indices {
            exercises[index].orderIndex = index
        }
        trainingExercisesByPhase[phaseID] = exercises
        try await saveExercises(planID: planID)
    }

    func instantiateExerciseTemplate(templateID: UUID, phaseID: UUID) async throws -> TrainingExercise {
        guard let template = trainingTemplates.first(where: { $0.id == templateID }) else {
            throw TrainingStoreError.exerciseNotFound
        }

        let created = try await addExercise(
            phaseID: phaseID,
            name: template.name,
            description: template.baseDescription,
            durationMinutes: template.defaultDuration,
            intensity: template.defaultIntensity,
            requiredPlayers: template.defaultRequiredPlayers
        )
        var updated = created
        updated.templateSourceID = templateID
        updated.materials = template.defaultMaterials
        return try await updateExercise(updated)
    }

    func saveExerciseAsTemplate(exerciseID: UUID, name: String?) async throws -> TrainingExerciseTemplate {
        guard !AppConfiguration.isPlaceholder else {
            throw TrainingStoreError.backendUnavailable
        }
        guard let exercise = findExercise(exerciseID) else {
            throw TrainingStoreError.exerciseNotFound
        }

        let templateName = (name ?? exercise.name).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !templateName.isEmpty else {
            throw TrainingStoreError.invalidTitle
        }

        let dto = try await backend.createTrainingTemplate(
            CreateTrainingTemplateRequest(
                name: templateName,
                baseDescription: exercise.description,
                defaultDuration: exercise.durationMinutes,
                defaultIntensity: exercise.intensity.rawValue,
                defaultRequiredPlayers: exercise.requiredPlayers,
                defaultMaterials: exercise.materials.map(mapMaterialDTO(from:))
            )
        )

        let template = mapTrainingTemplate(dto: dto)
        upsertTrainingTemplate(template)
        return template
    }

    func assignPlayersToPlan(planID: UUID, availability: [TrainingAvailabilitySnapshot]) async throws {
        guard !AppConfiguration.isPlaceholder else {
            throw TrainingStoreError.backendUnavailable
        }
        guard let backendPlanID = backendPlanID(for: planID) else {
            throw TrainingStoreError.planNotFound
        }

        let payload = AssignTrainingParticipantsRequest(
            availability: availability.map {
                TrainingAvailabilitySnapshotDTO(
                    playerID: $0.playerID,
                    availability: $0.availability.rawValue,
                    isAbsent: $0.isAbsent,
                    isLimited: $0.isLimited,
                    note: $0.note
                )
            }
        )
        let response = try await backend.assignTrainingParticipants(planID: backendPlanID, request: payload)
        trainingAvailabilityByPlan[planID] = response.map {
            TrainingAvailabilitySnapshot(
                playerID: $0.playerID,
                availability: AvailabilityStatus.fromBackend($0.availability),
                isAbsent: $0.isAbsent,
                isLimited: $0.isLimited,
                note: $0.note
            )
        }
    }

    func createOrUpdateGroup(
        planID: UUID,
        groupID: UUID? = nil,
        name: String,
        goal: String,
        playerIDs: [UUID],
        headCoachUserID: String,
        assistantCoachUserID: String?
    ) async throws -> TrainingGroup {
        guard !AppConfiguration.isPlaceholder else {
            throw TrainingStoreError.backendUnavailable
        }
        guard let backendPlanID = backendPlanID(for: planID) else {
            throw TrainingStoreError.planNotFound
        }

        let request = UpsertTrainingGroupRequest(
            id: groupID.flatMap { backendGroupID(for: $0, in: planID) },
            name: name,
            goal: goal,
            playerIDs: playerIDs,
            headCoachUserID: headCoachUserID,
            assistantCoachUserID: assistantCoachUserID
        )

        let dto: TrainingGroupDTO
        if let groupID,
           let backendGroupID = backendGroupID(for: groupID, in: planID) {
            dto = try await backend.updateTrainingGroup(groupID: backendGroupID, request: request)
        } else {
            dto = try await backend.createTrainingGroup(planID: backendPlanID, request: request)
        }

        let group = mapTrainingGroup(dto: dto, planID: planID)
        var groups = trainingGroupsByPlan[planID] ?? []
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        } else {
            groups.append(group)
        }
        trainingGroupsByPlan[planID] = groups
        return group
    }

    func saveGroupBriefing(groupID: UUID, briefing: TrainingGroupBriefing) async throws -> TrainingGroupBriefing {
        guard !AppConfiguration.isPlaceholder else {
            throw TrainingStoreError.backendUnavailable
        }

        guard let backendGroupID = backendGroupID(for: groupID) else {
            throw TrainingStoreError.groupNotFound
        }

        let request = SaveTrainingGroupBriefingRequest(
            goal: briefing.goal,
            coachingPoints: briefing.coachingPoints,
            focusPoints: briefing.focusPoints,
            commonMistakes: briefing.commonMistakes,
            targetIntensity: briefing.targetIntensity.rawValue
        )
        let dto = try await backend.saveTrainingGroupBriefing(groupID: backendGroupID, request: request)
        let mapped = mapTrainingGroupBriefing(dto: dto, groupID: groupID)
        trainingBriefingsByGroup[groupID] = mapped
        return mapped
    }

    func startLiveMode(planID: UUID) async throws {
        guard !AppConfiguration.isPlaceholder else {
            throw TrainingStoreError.backendUnavailable
        }
        guard let backendPlanID = backendPlanID(for: planID) else {
            throw TrainingStoreError.planNotFound
        }

        let dto = try await backend.startTrainingLive(
            planID: backendPlanID,
            request: StartTrainingLiveRequest(startedAt: Date())
        )

        var updated = mapTrainingPlan(dto: dto, fallbackLocalID: planID)
        updated.status = .live
        upsertTrainingPlan(updated)
    }

    func completePhaseLive(planID: UUID, phaseID: UUID, completed: Bool) async throws {
        guard var phases = trainingPhasesByPlan[planID],
              let index = phases.firstIndex(where: { $0.id == phaseID }) else {
            throw TrainingStoreError.phaseNotFound
        }

        phases[index].isCompletedLive = completed
        try await saveLiveState(planID: planID, phases: phases, exercisesByPhase: trainingExercisesByPhase)
    }

    func adjustExerciseLive(planID: UUID, exerciseID: UUID, actualDurationMinutes: Int?, skipped: Bool) async throws {
        guard let phaseID = findExercisePhaseID(exerciseID),
              var exercises = trainingExercisesByPhase[phaseID],
              let index = exercises.firstIndex(where: { $0.id == exerciseID }) else {
            throw TrainingStoreError.exerciseNotFound
        }

        exercises[index].actualDurationMinutes = actualDurationMinutes
        exercises[index].isSkippedLive = skipped
        trainingExercisesByPhase[phaseID] = exercises
        try await saveLiveState(planID: planID, phases: trainingPhasesByPlan[planID] ?? [], exercisesByPhase: trainingExercisesByPhase)
    }

    func recordLiveDeviation(
        planID: UUID,
        phaseID: UUID?,
        exerciseID: UUID?,
        kind: TrainingLiveDeviationKind,
        plannedValue: String,
        actualValue: String,
        note: String
    ) async throws -> TrainingLiveDeviation {
        guard !AppConfiguration.isPlaceholder else {
            throw TrainingStoreError.backendUnavailable
        }
        guard let backendPlanID = backendPlanID(for: planID) else {
            throw TrainingStoreError.planNotFound
        }

        let request = CreateTrainingLiveDeviationRequest(
            phaseID: phaseID.flatMap { backendPhaseID(for: $0, in: planID) },
            exerciseID: exerciseID.flatMap { backendExerciseID(for: $0) },
            kind: kind.rawValue,
            plannedValue: plannedValue,
            actualValue: actualValue,
            note: note,
            timestamp: Date()
        )

        let dto = try await backend.createTrainingLiveDeviation(planID: backendPlanID, request: request)
        let mapped = mapTrainingLiveDeviation(dto: dto, planID: planID)
        var deviations = trainingDeviationsByPlan[planID] ?? []
        deviations.append(mapped)
        deviations.sort { $0.timestamp > $1.timestamp }
        trainingDeviationsByPlan[planID] = deviations
        return mapped
    }

    func generateAndSaveTrainingReport(
        planID: UUID,
        summary: String,
        groupFeedback: [TrainingGroupFeedback],
        playerNotes: [TrainingPlayerNote]
    ) async throws -> TrainingReport {
        guard !AppConfiguration.isPlaceholder else {
            throw TrainingStoreError.backendUnavailable
        }
        guard let backendPlanID = backendPlanID(for: planID) else {
            throw TrainingStoreError.planNotFound
        }

        let phases = trainingPhasesByPlan[planID] ?? []
        let plannedTotal = phases.reduce(0) { $0 + $1.durationMinutes }

        let phaseIDs = Set(phases.map(\.id))
        let actualTotal = phaseIDs.reduce(0) { result, phaseID in
            let exercises = trainingExercisesByPhase[phaseID] ?? []
            let sum = exercises.reduce(0) { partial, exercise in
                if exercise.isSkippedLive {
                    return partial
                }
                return partial + exercise.effectiveDuration
            }
            return result + sum
        }

        let attendance = (trainingAvailabilityByPlan[planID] ?? []).map {
            TrainingAttendanceEntryDTO(
                playerID: $0.playerID,
                status: attendanceStatus(from: $0),
                note: $0.note
            )
        }

        let feedbackDTO = groupFeedback.compactMap { item -> TrainingGroupFeedbackDTO? in
            guard let backendGroupID = backendGroupID(for: item.groupID, in: planID) else { return nil }
            return TrainingGroupFeedbackDTO(
                id: item.id.uuidString,
                groupID: backendGroupID,
                trainerUserID: item.trainerUserID,
                feedback: item.feedback
            )
        }

        let reportDTO = try await backend.createTrainingReport(
            planID: backendPlanID,
            request: CreateTrainingReportRequest(
                plannedTotalMinutes: plannedTotal,
                actualTotalMinutes: actualTotal,
                attendance: attendance,
                groupFeedback: feedbackDTO,
                playerNotes: playerNotes.map { TrainingPlayerNoteDTO(playerID: $0.playerID, note: $0.note) },
                summary: summary
            )
        )

        let report = mapTrainingReport(dto: reportDTO, planID: planID)
        trainingReportsByPlan[planID] = report

        if let index = trainingPlans.firstIndex(where: { $0.id == planID }) {
            trainingPlans[index].status = .completed
            trainingPlans[index].updatedAt = Date()
            trainingPlans[index].syncState = .synced
        }

        return report
    }

    func linkTrainingToCalendar(planID: UUID, visibility: TrainingCalendarVisibility) async throws -> CalendarEvent {
        guard !AppConfiguration.isPlaceholder else {
            throw TrainingStoreError.backendUnavailable
        }
        guard let backendPlanID = backendPlanID(for: planID) else {
            throw TrainingStoreError.planNotFound
        }

        motionProgress(
            "Trainingsplan wird in Kalender eingetragen",
            subtitle: nil,
            progress: nil,
            scope: .trainingsplan,
            contextId: planID.uuidString
        )

        let dto: CalendarEventDTO
        do {
            dto = try await backend.linkTrainingToCalendar(
                planID: backendPlanID,
                request: LinkTrainingCalendarRequest(playersViewLevel: visibility.playersViewLevel.rawValue)
            )
        } catch {
            motionClearProgress()
            motionError(error, scope: .trainingsplan, title: "Kalender-Verknüpfung fehlgeschlagen", contextId: planID.uuidString)
            throw error
        }

        let event = CalendarEvent(
            id: dto.id,
            title: dto.title,
            startDate: dto.startDate,
            endDate: dto.endDate,
            categoryID: dto.categoryId,
            visibility: CalendarVisibility(rawValue: dto.visibility) ?? .team,
            audience: CalendarAudience(rawValue: dto.audience) ?? .team,
            audiencePlayerIDs: dto.audiencePlayerIds?.compactMap { UUID(uuidString: $0) } ?? [],
            recurrence: CalendarRecurrence(rawValue: dto.recurrence) ?? .none,
            location: dto.location ?? "",
            notes: dto.notes ?? "",
            linkedTrainingPlanID: dto.linkedTrainingPlanID.flatMap { UUID(uuidString: $0) } ?? planID,
            eventKind: CalendarEventKind(rawValue: dto.eventKind ?? "") ?? .training,
            playerVisibleGoal: dto.playerVisibleGoal,
            playerVisibleDurationMinutes: dto.playerVisibleDurationMinutes
        )

        if let index = calendarEvents.firstIndex(where: { $0.id == event.id }) {
            calendarEvents[index] = event
        } else {
            calendarEvents.append(event)
        }

        if let index = trainingPlans.firstIndex(where: { $0.id == planID }) {
            trainingPlans[index].calendarEventID = UUID(uuidString: event.id)
            trainingPlans[index].syncState = .synced
            trainingPlans[index].updatedAt = Date()
        }

        motionClearProgress()
        motionUpdate(
            "In Kalender eingetragen",
            subtitle: event.title,
            scope: .trainingsplan,
            contextId: planID.uuidString,
            icon: "calendar.badge.checkmark"
        )

        return event
    }

    func duplicatePlanAsTemplate(planID: UUID, templateName: String?) async throws -> TrainingPlan {
        guard !AppConfiguration.isPlaceholder else {
            throw TrainingStoreError.backendUnavailable
        }
        guard let backendPlanID = backendPlanID(for: planID) else {
            throw TrainingStoreError.planNotFound
        }

        let dto = try await backend.duplicateTrainingPlan(
            planID: backendPlanID,
            request: DuplicateTrainingPlanRequest(
                asTemplate: true,
                name: templateName,
                targetDate: nil
            )
        )
        let mapped = mapTrainingPlan(dto: dto)
        upsertTrainingPlan(mapped)
        return mapped
    }

    func instantiateFromTemplate(templateID: UUID, targetDate: Date, title: String?) async throws -> TrainingPlan {
        guard let template = trainingTemplates.first(where: { $0.id == templateID }) else {
            throw TrainingStoreError.exerciseNotFound
        }

        let draft = TrainingPlanDraft(
            title: title ?? template.name,
            date: targetDate,
            location: "",
            mainGoal: template.baseDescription,
            secondaryGoals: []
        )

        let plan = try await createTrainingPlan(draft)
        guard let mainPhase = trainingPhasesByPlan[plan.id]?.first(where: { $0.type == .main }) else {
            throw TrainingStoreError.phaseNotFound
        }

        _ = try await addExercise(
            phaseID: mainPhase.id,
            name: template.name,
            description: template.baseDescription,
            durationMinutes: template.defaultDuration,
            intensity: template.defaultIntensity,
            requiredPlayers: template.defaultRequiredPlayers
        )

        if let idx = trainingExercisesByPhase[mainPhase.id]?.indices.last {
            trainingExercisesByPhase[mainPhase.id]?[idx].materials = template.defaultMaterials
            try await saveExercises(planID: plan.id)
        }

        try await loadTrainingPlanDetails(planID: plan.id)
        return plan
    }

    func loadSummary(planID: UUID) -> TrainingLoadSummary {
        guard let phases = trainingPhasesByPlan[planID], !phases.isEmpty else {
            return .zero
        }

        let totalMinutes = phases.reduce(0) { $0 + $1.durationMinutes }
        let loadScore = phases.reduce(0) { $0 + ($1.durationMinutes * $1.intensity.loadFactor) }
        let highMinutes = phases
            .filter { $0.intensity == .high }
            .reduce(0) { $0 + $1.durationMinutes }

        let warning = hasConsecutiveHighLoad(for: planID, thresholdHighMinutes: 30)
        return TrainingLoadSummary(
            totalMinutes: totalMinutes,
            loadScore: loadScore,
            highIntensityMinutes: highMinutes,
            warningConsecutiveHighLoad: warning
        )
    }

    func sortedTrainingPlans() -> [TrainingPlan] {
        trainingPlans.sorted { $0.date < $1.date }
    }

    func phases(for planID: UUID) -> [TrainingPhase] {
        (trainingPhasesByPlan[planID] ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    func exercises(for phaseID: UUID) -> [TrainingExercise] {
        (trainingExercisesByPhase[phaseID] ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    func groups(for planID: UUID) -> [TrainingGroup] {
        (trainingGroupsByPlan[planID] ?? []).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func trainingReport(for planID: UUID) -> TrainingReport? {
        trainingReportsByPlan[planID]
    }

    private func loadTrainingPlanDetails(planID: UUID) async throws {
        guard let backendPlanID = backendPlanID(for: planID) else {
            throw TrainingStoreError.planNotFound
        }
        try await loadTrainingPlanDetails(backendPlanID: backendPlanID)
    }

    private func loadTrainingPlanDetails(backendPlanID: String) async throws {
        let envelope = try await backend.fetchTrainingPlan(planID: backendPlanID)
        let plan = mapTrainingPlan(dto: envelope.plan)
        upsertTrainingPlan(plan)

        let mappedPhases = envelope.phases.map { mapTrainingPhase(dto: $0, planID: plan.id) }
            .sorted { $0.orderIndex < $1.orderIndex }
        trainingPhasesByPlan[plan.id] = mappedPhases

        let phaseLookup: [String: UUID] = Dictionary(uniqueKeysWithValues: mappedPhases.compactMap { phase -> (String, UUID)? in
            guard let backendID = phase.backendID else { return nil }
            return (backendID, phase.id)
        })

        var exercisesByPhase: [UUID: [TrainingExercise]] = [:]
        for dto in envelope.exercises {
            guard let localPhaseID = phaseLookup[dto.phaseID] else { continue }
            var item = mapTrainingExercise(dto: dto, phaseID: localPhaseID)
            if let sourceID = dto.templateSourceID {
                item.templateSourceID = trainingTemplates.first(where: { $0.backendID == sourceID })?.id
            }
            exercisesByPhase[localPhaseID, default: []].append(item)
        }
        for phaseID in exercisesByPhase.keys {
            exercisesByPhase[phaseID]?.sort { $0.orderIndex < $1.orderIndex }
        }
        let mappedPhaseIDs = Set(mappedPhases.map(\.id))
        for phaseID in mappedPhaseIDs {
            trainingExercisesByPhase.removeValue(forKey: phaseID)
        }
        trainingExercisesByPhase.merge(exercisesByPhase) { _, new in new }

        let mappedGroups = envelope.groups.map { mapTrainingGroup(dto: $0, planID: plan.id) }
        trainingGroupsByPlan[plan.id] = mappedGroups
        let groupLookup: [String: UUID] = Dictionary(uniqueKeysWithValues: mappedGroups.compactMap { group -> (String, UUID)? in
            guard let backendID = group.backendID else { return nil }
            return (backendID, group.id)
        })

        var briefings: [UUID: TrainingGroupBriefing] = [:]
        for dto in envelope.briefings {
            guard let localGroupID = groupLookup[dto.groupID] else { continue }
            briefings[localGroupID] = mapTrainingGroupBriefing(dto: dto, groupID: localGroupID)
        }
        trainingBriefingsByGroup.merge(briefings) { _, new in new }

        trainingAvailabilityByPlan[plan.id] = envelope.availability.map {
            TrainingAvailabilitySnapshot(
                playerID: $0.playerID,
                availability: AvailabilityStatus.fromBackend($0.availability),
                isAbsent: $0.isAbsent,
                isLimited: $0.isLimited,
                note: $0.note
            )
        }

        trainingDeviationsByPlan[plan.id] = envelope.deviations.map {
            mapTrainingLiveDeviation(dto: $0, planID: plan.id)
        }

        if let reportDTO = envelope.report {
            trainingReportsByPlan[plan.id] = mapTrainingReport(dto: reportDTO, planID: plan.id)
        }

        activeTrainingPlanID = plan.id
    }

    private func savePhases(planID: UUID, phases: [TrainingPhase]) async throws -> [TrainingPhase] {
        guard !AppConfiguration.isPlaceholder else {
            throw TrainingStoreError.backendUnavailable
        }
        guard let backendPlanID = backendPlanID(for: planID) else {
            throw TrainingStoreError.planNotFound
        }

        var payload = phases
        for index in payload.indices {
            payload[index].orderIndex = index
        }

        let response = try await backend.saveTrainingPhases(
            planID: backendPlanID,
            request: SaveTrainingPhasesRequest(phases: payload.map { mapPhaseDTO(from: $0, backendPlanID: backendPlanID) })
        )

        let mapped = response.map { mapTrainingPhase(dto: $0, planID: planID) }
            .sorted { $0.orderIndex < $1.orderIndex }
        trainingPhasesByPlan[planID] = mapped
        return mapped
    }

    private func saveExercises(planID: UUID) async throws {
        guard !AppConfiguration.isPlaceholder else {
            throw TrainingStoreError.backendUnavailable
        }
        guard let backendPlanID = backendPlanID(for: planID) else {
            throw TrainingStoreError.planNotFound
        }

        let phaseMap: [UUID: String] = Dictionary(uniqueKeysWithValues: (trainingPhasesByPlan[planID] ?? []).compactMap { phase -> (UUID, String)? in
            guard let backendID = phase.backendID else { return nil }
            return (phase.id, backendID)
        })

        var flat: [TrainingExerciseDTO] = []
        let sortedPhases = phases(for: planID)
        for phase in sortedPhases {
            guard let backendPhaseID = phaseMap[phase.id] else { continue }
            let exercises = self.exercises(for: phase.id)
            for exercise in exercises {
                flat.append(mapExerciseDTO(from: exercise, backendPhaseID: backendPhaseID))
            }
        }

        let response = try await backend.saveTrainingExercises(
            planID: backendPlanID,
            request: SaveTrainingExercisesRequest(exercises: flat)
        )

        var mappedByPhase: [UUID: [TrainingExercise]] = [:]
        let backendToLocalPhase: [String: UUID] = Dictionary(uniqueKeysWithValues: sortedPhases.compactMap { phase -> (String, UUID)? in
            guard let backend = phase.backendID else { return nil }
            return (backend, phase.id)
        })

        for dto in response {
            guard let localPhaseID = backendToLocalPhase[dto.phaseID] else { continue }
            let mapped = mapTrainingExercise(dto: dto, phaseID: localPhaseID)
            mappedByPhase[localPhaseID, default: []].append(mapped)
        }

        for key in mappedByPhase.keys {
            mappedByPhase[key]?.sort { $0.orderIndex < $1.orderIndex }
            trainingExercisesByPhase[key] = mappedByPhase[key]
        }
    }

    private func saveLiveState(
        planID: UUID,
        phases: [TrainingPhase],
        exercisesByPhase: [UUID: [TrainingExercise]]
    ) async throws {
        guard !AppConfiguration.isPlaceholder else {
            throw TrainingStoreError.backendUnavailable
        }
        guard let backendPlanID = backendPlanID(for: planID) else {
            throw TrainingStoreError.planNotFound
        }

        let backendPhaseMap: [UUID: String] = Dictionary(uniqueKeysWithValues: (trainingPhasesByPlan[planID] ?? []).compactMap { phase -> (UUID, String)? in
            guard let backendID = phase.backendID else { return nil }
            return (phase.id, backendID)
        })

        let phaseDTOs = phases.map { mapPhaseDTO(from: $0, backendPlanID: backendPlanID) }

        var exerciseDTOs: [TrainingExerciseDTO] = []
        for phase in phases {
            guard let backendPhaseID = backendPhaseMap[phase.id] else { continue }
            for exercise in (exercisesByPhase[phase.id] ?? []) {
                exerciseDTOs.append(mapExerciseDTO(from: exercise, backendPhaseID: backendPhaseID))
            }
        }

        let envelope = try await backend.saveTrainingLiveState(
            planID: backendPlanID,
            request: SaveTrainingLiveStateRequest(phases: phaseDTOs, exercises: exerciseDTOs)
        )

        let mappedPlan = mapTrainingPlan(dto: envelope.plan, fallbackLocalID: planID)
        upsertTrainingPlan(mappedPlan)

        let mappedPhases = envelope.phases.map { mapTrainingPhase(dto: $0, planID: planID) }
            .sorted { $0.orderIndex < $1.orderIndex }
        trainingPhasesByPlan[planID] = mappedPhases

        let backendToLocalPhase: [String: UUID] = Dictionary(uniqueKeysWithValues: mappedPhases.compactMap { phase -> (String, UUID)? in
            guard let backend = phase.backendID else { return nil }
            return (backend, phase.id)
        })

        var mappedExercises: [UUID: [TrainingExercise]] = [:]
        for dto in envelope.exercises {
            guard let localPhaseID = backendToLocalPhase[dto.phaseID] else { continue }
            mappedExercises[localPhaseID, default: []].append(mapTrainingExercise(dto: dto, phaseID: localPhaseID))
        }
        for key in mappedExercises.keys {
            mappedExercises[key]?.sort { $0.orderIndex < $1.orderIndex }
            trainingExercisesByPhase[key] = mappedExercises[key]
        }
    }

    private func upsertTrainingPlan(_ plan: TrainingPlan) {
        if let index = trainingPlans.firstIndex(where: { $0.id == plan.id || ($0.backendID != nil && $0.backendID == plan.backendID) }) {
            trainingPlans[index] = plan
        } else {
            trainingPlans.append(plan)
        }
        trainingPlans.sort { $0.date < $1.date }
    }

    private func upsertTrainingTemplate(_ template: TrainingExerciseTemplate) {
        if let index = trainingTemplates.firstIndex(where: { $0.id == template.id || ($0.backendID != nil && $0.backendID == template.backendID) }) {
            trainingTemplates[index] = template
        } else {
            trainingTemplates.append(template)
        }
        trainingTemplates.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func mapTrainingPlan(dto: TrainingPlanDTO, fallbackLocalID: UUID? = nil) -> TrainingPlan {
        let localID = fallbackLocalID
            ?? trainingPlans.first(where: { $0.backendID == dto.id })?.id
            ?? UUID()
        return TrainingPlan(
            id: localID,
            backendID: dto.id,
            title: dto.title,
            date: dto.date,
            location: dto.location,
            mainGoal: dto.mainGoal,
            secondaryGoals: dto.secondaryGoals,
            status: TrainingPlanStatus(rawValue: dto.status) ?? .draft,
            linkedMatchID: dto.linkedMatchID,
            calendarEventID: dto.calendarEventID,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            syncState: .synced
        )
    }

    private func mapTrainingPhase(dto: TrainingPhaseDTO, planID: UUID) -> TrainingPhase {
        let existing = (trainingPhasesByPlan[planID] ?? []).first(where: { $0.backendID == dto.id })
        return TrainingPhase(
            id: existing?.id ?? UUID(),
            backendID: dto.id,
            planID: planID,
            orderIndex: dto.orderIndex,
            type: TrainingPhaseType(rawValue: dto.type) ?? .main,
            title: dto.title,
            durationMinutes: dto.durationMinutes,
            goal: dto.goal,
            intensity: TrainingIntensity(rawValue: dto.intensity) ?? .medium,
            description: dto.description,
            isCompletedLive: dto.isCompletedLive
        )
    }

    private func mapTrainingExercise(dto: TrainingExerciseDTO, phaseID: UUID) -> TrainingExercise {
        let existing = (trainingExercisesByPhase[phaseID] ?? []).first(where: { $0.backendID == dto.id })
        return TrainingExercise(
            id: existing?.id ?? UUID(),
            backendID: dto.id,
            phaseID: phaseID,
            orderIndex: dto.orderIndex,
            name: dto.name,
            description: dto.description,
            durationMinutes: dto.durationMinutes,
            intensity: TrainingIntensity(rawValue: dto.intensity) ?? .medium,
            requiredPlayers: dto.requiredPlayers,
            materials: dto.materials.map(mapMaterial(from:)),
            excludedPlayerIDs: dto.excludedPlayerIDs,
            templateSourceID: existing?.templateSourceID,
            isSkippedLive: dto.isSkippedLive,
            actualDurationMinutes: dto.actualDurationMinutes
        )
    }

    private func mapTrainingTemplate(dto: TrainingExerciseTemplateDTO) -> TrainingExerciseTemplate {
        let existing = trainingTemplates.first(where: { $0.backendID == dto.id })
        return TrainingExerciseTemplate(
            id: existing?.id ?? UUID(),
            backendID: dto.id,
            name: dto.name,
            baseDescription: dto.baseDescription,
            defaultDuration: dto.defaultDuration,
            defaultIntensity: TrainingIntensity(rawValue: dto.defaultIntensity) ?? .medium,
            defaultRequiredPlayers: dto.defaultRequiredPlayers,
            defaultMaterials: dto.defaultMaterials.map(mapMaterial(from:))
        )
    }

    private func mapTrainingGroup(dto: TrainingGroupDTO, planID: UUID) -> TrainingGroup {
        let existing = (trainingGroupsByPlan[planID] ?? []).first(where: { $0.backendID == dto.id })
        return TrainingGroup(
            id: existing?.id ?? UUID(),
            backendID: dto.id,
            planID: planID,
            name: dto.name,
            goal: dto.goal,
            playerIDs: dto.playerIDs,
            headCoachUserID: dto.headCoachUserID,
            assistantCoachUserID: dto.assistantCoachUserID
        )
    }

    private func mapTrainingGroupBriefing(dto: TrainingGroupBriefingDTO, groupID: UUID) -> TrainingGroupBriefing {
        let existing = trainingBriefingsByGroup[groupID]
        return TrainingGroupBriefing(
            id: existing?.id ?? UUID(),
            backendID: dto.id,
            groupID: groupID,
            goal: dto.goal,
            coachingPoints: dto.coachingPoints,
            focusPoints: dto.focusPoints,
            commonMistakes: dto.commonMistakes,
            targetIntensity: TrainingIntensity(rawValue: dto.targetIntensity) ?? .medium
        )
    }

    private func mapTrainingReport(dto: TrainingReportDTO, planID: UUID) -> TrainingReport {
        let existing = trainingReportsByPlan[planID]
        return TrainingReport(
            id: existing?.id ?? UUID(),
            backendID: dto.id,
            planID: planID,
            generatedAt: dto.generatedAt,
            plannedTotalMinutes: dto.plannedTotalMinutes,
            actualTotalMinutes: dto.actualTotalMinutes,
            attendance: dto.attendance.map { TrainingAttendanceEntry(playerID: $0.playerID, status: $0.status, note: $0.note) },
            groupFeedback: dto.groupFeedback.map { item in
                let groupID = trainingGroupsByPlan[planID]?.first(where: { $0.backendID == item.groupID })?.id ?? UUID()
                return TrainingGroupFeedback(id: UUID(uuidString: item.id) ?? UUID(), groupID: groupID, trainerUserID: item.trainerUserID, feedback: item.feedback)
            },
            playerNotes: dto.playerNotes.map { TrainingPlayerNote(playerID: $0.playerID, note: $0.note) },
            summary: dto.summary
        )
    }

    private func mapTrainingLiveDeviation(dto: TrainingLiveDeviationDTO, planID: UUID) -> TrainingLiveDeviation {
        let localPhaseID = dto.phaseID.flatMap { backend in
            trainingPhasesByPlan[planID]?.first(where: { $0.backendID == backend })?.id
        }
        let localExerciseID = dto.exerciseID.flatMap { backend in
            trainingExercisesByPhase.values
                .flatMap { $0 }
                .first(where: { $0.backendID == backend })?
                .id
        }

        return TrainingLiveDeviation(
            id: UUID(uuidString: dto.id) ?? UUID(),
            backendID: dto.id,
            planID: planID,
            phaseID: localPhaseID,
            exerciseID: localExerciseID,
            kind: TrainingLiveDeviationKind(rawValue: dto.kind) ?? .timeAdjusted,
            plannedValue: dto.plannedValue,
            actualValue: dto.actualValue,
            note: dto.note,
            timestamp: dto.timestamp
        )
    }

    private func mapPhaseDTO(from phase: TrainingPhase, backendPlanID: String) -> TrainingPhaseDTO {
        TrainingPhaseDTO(
            id: phase.backendID ?? phase.id.uuidString,
            planID: backendPlanID,
            orderIndex: phase.orderIndex,
            type: phase.type.rawValue,
            title: phase.title,
            durationMinutes: phase.durationMinutes,
            goal: phase.goal,
            intensity: phase.intensity.rawValue,
            description: phase.description,
            isCompletedLive: phase.isCompletedLive
        )
    }

    private func mapExerciseDTO(from exercise: TrainingExercise, backendPhaseID: String) -> TrainingExerciseDTO {
        TrainingExerciseDTO(
            id: exercise.backendID ?? exercise.id.uuidString,
            phaseID: backendPhaseID,
            orderIndex: exercise.orderIndex,
            name: exercise.name,
            description: exercise.description,
            durationMinutes: exercise.durationMinutes,
            intensity: exercise.intensity.rawValue,
            requiredPlayers: exercise.requiredPlayers,
            materials: exercise.materials.map(mapMaterialDTO(from:)),
            excludedPlayerIDs: exercise.excludedPlayerIDs,
            templateSourceID: exercise.templateSourceID.flatMap { templateID in
                trainingTemplates.first(where: { $0.id == templateID })?.backendID
            },
            isSkippedLive: exercise.isSkippedLive,
            actualDurationMinutes: exercise.actualDurationMinutes
        )
    }

    private func mapMaterial(from dto: TrainingMaterialQuantityDTO) -> TrainingMaterialQuantity {
        TrainingMaterialQuantity(
            kind: TrainingMaterialKind(rawValue: dto.kind) ?? .sonstiges,
            label: dto.label,
            quantity: dto.quantity
        )
    }

    private func mapMaterialDTO(from material: TrainingMaterialQuantity) -> TrainingMaterialQuantityDTO {
        TrainingMaterialQuantityDTO(
            kind: material.kind.rawValue,
            label: material.label,
            quantity: material.quantity
        )
    }

    private func backendPlanID(for planID: UUID) -> String? {
        trainingPlans.first(where: { $0.id == planID })?.backendID
    }

    private func planID(forPhaseID phaseID: UUID) -> UUID? {
        for (planID, phases) in trainingPhasesByPlan where phases.contains(where: { $0.id == phaseID }) {
            return planID
        }
        return nil
    }

    private func backendPhaseID(for phaseID: UUID, in planID: UUID) -> String? {
        trainingPhasesByPlan[planID]?.first(where: { $0.id == phaseID })?.backendID
    }

    private func findExercise(_ exerciseID: UUID) -> TrainingExercise? {
        trainingExercisesByPhase.values
            .flatMap { $0 }
            .first(where: { $0.id == exerciseID })
    }

    private func findExercisePhaseID(_ exerciseID: UUID) -> UUID? {
        for (phaseID, exercises) in trainingExercisesByPhase where exercises.contains(where: { $0.id == exerciseID }) {
            return phaseID
        }
        return nil
    }

    private func backendExerciseID(for exerciseID: UUID) -> String? {
        findExercise(exerciseID)?.backendID
    }

    private func backendGroupID(for groupID: UUID, in planID: UUID? = nil) -> String? {
        if let planID {
            return trainingGroupsByPlan[planID]?.first(where: { $0.id == groupID })?.backendID
        }
        for groups in trainingGroupsByPlan.values {
            if let id = groups.first(where: { $0.id == groupID })?.backendID {
                return id
            }
        }
        return nil
    }

    private func attendanceStatus(from snapshot: TrainingAvailabilitySnapshot) -> String {
        if snapshot.isAbsent {
            return "abwesend"
        }
        if snapshot.isLimited {
            return "eingeschränkt"
        }
        return snapshot.availability.rawValue
    }

    private func hasConsecutiveHighLoad(for planID: UUID, thresholdHighMinutes: Int) -> Bool {
        guard let current = trainingPlans.first(where: { $0.id == planID }) else {
            return false
        }

        let calendar = Calendar.current
        let currentDay = calendar.startOfDay(for: current.date)
        let neighbors = trainingPlans.filter {
            let day = calendar.startOfDay(for: $0.date)
            return abs(day.timeIntervalSince(currentDay)) <= 86400
        }

        let highCount = neighbors.filter { plan in
            let summary = loadSummary(planID: plan.id)
            return summary.highIntensityMinutes >= thresholdHighMinutes
        }.count

        return highCount >= 2
    }
}
