import SwiftUI

struct TrainingPlanningWorkspaceView: View {
    @EnvironmentObject private var dataStore: AppDataStore

    @StateObject private var workspaceViewModel = TrainingPlanningWorkspaceViewModel()
    @StateObject private var editorViewModel = TrainingPlanEditorViewModel()
    @StateObject private var groupViewModel = TrainingGroupViewModel()
    @StateObject private var liveViewModel = TrainingLiveViewModel()
    @StateObject private var reportViewModel = TrainingReportViewModel()
    private let loadViewModel = TrainingLoadViewModel()

    @State private var includeGoalInCalendar = true

    private var activePlan: TrainingPlan? {
        workspaceViewModel.activePlan(in: dataStore)
    }

    private var combinedStatusMessage: String? {
        workspaceViewModel.statusMessage
            ?? editorViewModel.statusMessage
            ?? groupViewModel.statusMessage
            ?? liveViewModel.statusMessage
            ?? reportViewModel.statusMessage
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                TrainingPlanToolbarView(
                    plans: dataStore.sortedTrainingPlans(),
                    selectedPlanID: Binding(
                        get: { workspaceViewModel.selectedPlanID },
                        set: { workspaceViewModel.selectPlan($0, store: dataStore) }
                    ),
                    selectedSection: $workspaceViewModel.selectedSection,
                    title: $workspaceViewModel.draftTitle,
                    date: $workspaceViewModel.draftDate,
                    location: $workspaceViewModel.draftLocation,
                    mainGoal: $workspaceViewModel.draftMainGoal,
                    secondaryGoalsText: $workspaceViewModel.draftSecondaryGoals,
                    includeGoalInCalendar: $includeGoalInCalendar,
                    isBusy: workspaceViewModel.isBootstrapping || workspaceViewModel.isSaving,
                    onCreate: {
                        Task { await workspaceViewModel.createPlan(store: dataStore) }
                    },
                    onSave: {
                        Task { await workspaceViewModel.savePlan(store: dataStore) }
                    },
                    onDelete: {
                        Task { await workspaceViewModel.deleteActivePlan(store: dataStore) }
                    },
                    onDuplicateTemplate: {
                        Task { await workspaceViewModel.duplicateAsTemplate(store: dataStore) }
                    },
                    onLinkToCalendar: {
                        Task { await workspaceViewModel.linkToCalendar(store: dataStore, includeGoal: includeGoalInCalendar) }
                    },
                    onStartLive: {
                        Task {
                            await workspaceViewModel.startLiveMode(store: dataStore)
                            if let planID = activePlan?.id {
                                liveViewModel.prepare(planID: planID, store: dataStore)
                            }
                        }
                    },
                    onReload: {
                        Task { await workspaceViewModel.bootstrap(store: dataStore) }
                    }
                )

                if dataStore.trainingConnectionState == .syncing && dataStore.trainingPlans.isEmpty {
                    loadingState
                } else if case .failed(let reason) = dataStore.trainingConnectionState, dataStore.trainingPlans.isEmpty {
                    failedState(reason)
                } else if let plan = activePlan {
                    switch workspaceViewModel.selectedSection {
                    case .planung:
                        planningContent(plan: plan, size: proxy.size)
                    case .live:
                        TrainingLiveModeView(
                            plan: plan,
                            phases: dataStore.phases(for: plan.id),
                            exercisesForPhase: { phaseID in
                                dataStore.exercises(for: phaseID)
                            },
                            deviations: dataStore.trainingDeviationsByPlan[plan.id] ?? [],
                            viewModel: liveViewModel,
                            onStartLive: {
                                Task { await liveViewModel.start(planID: plan.id, store: dataStore) }
                            },
                            onTogglePhaseCompletion: { phase in
                                Task { await liveViewModel.togglePhaseCompletion(planID: plan.id, phase: phase, store: dataStore) }
                            },
                            onChangeExerciseDuration: { exercise, minutes in
                                Task { await liveViewModel.setExerciseDuration(planID: plan.id, exercise: exercise, minutes: minutes, store: dataStore) }
                            },
                            onToggleExerciseSkip: { exercise in
                                Task { await liveViewModel.toggleExerciseSkip(planID: plan.id, exercise: exercise, store: dataStore) }
                            },
                            onExtendExercise: { exercise, delta in
                                Task { await liveViewModel.extendExercise(planID: plan.id, exercise: exercise, delta: delta, store: dataStore) }
                            }
                        )
                        .padding(12)
                    case .bericht:
                        TrainingReportView(
                            plan: plan,
                            players: dataStore.players,
                            groups: dataStore.groups(for: plan.id),
                            availability: dataStore.trainingAvailabilityByPlan[plan.id] ?? [],
                            existingReport: dataStore.trainingReport(for: plan.id),
                            viewModel: reportViewModel,
                            onGenerate: {
                                Task {
                                    let userID = dataStore.messengerCurrentUser?.userID ?? "trainer.main"
                                    await reportViewModel.generate(planID: plan.id, store: dataStore, currentUserID: userID)
                                }
                            }
                        )
                        .padding(12)
                    }
                } else {
                    emptyState
                }

                if let status = combinedStatusMessage, !status.isEmpty {
                    HStack {
                        Text(status)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.surface)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(AppTheme.border)
                            .frame(height: 1)
                    }
                }
            }
            .background(AppTheme.background)
            .environment(\.colorScheme, .light)
            .onAppear {
                Task {
                    await workspaceViewModel.bootstrapIfNeeded(store: dataStore)
                    if let plan = activePlan {
                        editorViewModel.ensureSelection(planID: plan.id, store: dataStore)
                        groupViewModel.load(planID: plan.id, store: dataStore)
                        liveViewModel.prepare(planID: plan.id, store: dataStore)
                        reportViewModel.prepare(planID: plan.id, store: dataStore)
                    }
                }
            }
            .onChange(of: workspaceViewModel.selectedPlanID) { _, _ in
                guard let plan = activePlan else { return }
                editorViewModel.ensureSelection(planID: plan.id, store: dataStore)
                groupViewModel.load(planID: plan.id, store: dataStore)
                liveViewModel.prepare(planID: plan.id, store: dataStore)
                reportViewModel.prepare(planID: plan.id, store: dataStore)
            }
            .onReceive(NotificationCenter.default.publisher(for: .trainingCommandCreatePlan)) { _ in
                Task { await workspaceViewModel.createPlan(store: dataStore) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .trainingCommandStartLive)) { _ in
                Task {
                    await workspaceViewModel.startLiveMode(store: dataStore)
                    if let planID = activePlan?.id {
                        liveViewModel.prepare(planID: planID, store: dataStore)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .trainingCommandCompleteStep)) { _ in
                guard let plan = activePlan,
                      let phase = dataStore.phases(for: plan.id).first(where: { !$0.isCompletedLive }) else {
                    return
                }
                Task {
                    await liveViewModel.togglePhaseCompletion(planID: plan.id, phase: phase, store: dataStore)
                }
            }
        }
    }

    @ViewBuilder
    private func planningContent(plan: TrainingPlan, size: CGSize) -> some View {
        let compact = size.width < 1180 || size.height < 700

        if compact {
            ScrollView {
                VStack(spacing: 12) {
                    TrainingPlanListView(
                        plans: dataStore.sortedTrainingPlans(),
                        selectedPlanID: workspaceViewModel.selectedPlanID,
                        onSelect: { workspaceViewModel.selectPlan($0, store: dataStore) }
                    )
                    .frame(maxWidth: .infinity)

                    TrainingPhaseEditorView(
                        plan: plan,
                        phases: dataStore.phases(for: plan.id),
                        selectedPhaseID: $editorViewModel.selectedPhaseID,
                        newPhaseType: $editorViewModel.newPhaseType,
                        newExerciseName: $editorViewModel.newExerciseName,
                        exercisesForPhase: { phaseID in
                            dataStore.exercises(for: phaseID)
                        },
                        onAddPhase: {
                            Task { await editorViewModel.addPhase(planID: plan.id, store: dataStore) }
                        },
                        onMovePhase: { from, to in
                            Task { await editorViewModel.movePhase(planID: plan.id, from: from, to: to, store: dataStore) }
                        },
                        onSavePhase: { phase in
                            Task { await editorViewModel.savePhase(planID: plan.id, phase: phase, store: dataStore) }
                        },
                        onDuplicatePhase: { phase in
                            Task { await editorViewModel.duplicatePhase(planID: plan.id, phaseID: phase.id, store: dataStore) }
                        },
                        onDeletePhase: { phase in
                            Task { await editorViewModel.deletePhase(planID: plan.id, phaseID: phase.id, store: dataStore) }
                        },
                        onAddExercise: { phaseID in
                            Task { await editorViewModel.addExercise(to: phaseID, store: dataStore) }
                        },
                        onMoveExercise: { phaseID, from, to in
                            Task { await editorViewModel.moveExercise(phaseID: phaseID, from: from, to: to, store: dataStore) }
                        },
                        onSaveExercise: { exercise in
                            Task { await editorViewModel.saveExercise(exercise, store: dataStore) }
                        },
                        onDuplicateExercise: { phaseID, exerciseID in
                            Task { await editorViewModel.duplicateExercise(phaseID: phaseID, exerciseID: exerciseID, store: dataStore) }
                        },
                        onDeleteExercise: { phaseID, exerciseID in
                            Task { await editorViewModel.deleteExercise(phaseID: phaseID, exerciseID: exerciseID, store: dataStore) }
                        },
                        onSaveExerciseAsTemplate: { exerciseID, customName in
                            Task { await editorViewModel.saveExerciseAsTemplate(exerciseID: exerciseID, customName: customName, store: dataStore) }
                        }
                    )

                    sidebarPanels(plan: plan)
                }
                .padding(12)
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 12) {
                    TrainingPlanListView(
                        plans: dataStore.sortedTrainingPlans(),
                        selectedPlanID: workspaceViewModel.selectedPlanID,
                        onSelect: { workspaceViewModel.selectPlan($0, store: dataStore) }
                    )
                    .frame(height: 170)

                    TrainingPhaseEditorView(
                        plan: plan,
                        phases: dataStore.phases(for: plan.id),
                        selectedPhaseID: $editorViewModel.selectedPhaseID,
                        newPhaseType: $editorViewModel.newPhaseType,
                        newExerciseName: $editorViewModel.newExerciseName,
                        exercisesForPhase: { phaseID in
                            dataStore.exercises(for: phaseID)
                        },
                        onAddPhase: {
                            Task { await editorViewModel.addPhase(planID: plan.id, store: dataStore) }
                        },
                        onMovePhase: { from, to in
                            Task { await editorViewModel.movePhase(planID: plan.id, from: from, to: to, store: dataStore) }
                        },
                        onSavePhase: { phase in
                            Task { await editorViewModel.savePhase(planID: plan.id, phase: phase, store: dataStore) }
                        },
                        onDuplicatePhase: { phase in
                            Task { await editorViewModel.duplicatePhase(planID: plan.id, phaseID: phase.id, store: dataStore) }
                        },
                        onDeletePhase: { phase in
                            Task { await editorViewModel.deletePhase(planID: plan.id, phaseID: phase.id, store: dataStore) }
                        },
                        onAddExercise: { phaseID in
                            Task { await editorViewModel.addExercise(to: phaseID, store: dataStore) }
                        },
                        onMoveExercise: { phaseID, from, to in
                            Task { await editorViewModel.moveExercise(phaseID: phaseID, from: from, to: to, store: dataStore) }
                        },
                        onSaveExercise: { exercise in
                            Task { await editorViewModel.saveExercise(exercise, store: dataStore) }
                        },
                        onDuplicateExercise: { phaseID, exerciseID in
                            Task { await editorViewModel.duplicateExercise(phaseID: phaseID, exerciseID: exerciseID, store: dataStore) }
                        },
                        onDeleteExercise: { phaseID, exerciseID in
                            Task { await editorViewModel.deleteExercise(phaseID: phaseID, exerciseID: exerciseID, store: dataStore) }
                        },
                        onSaveExerciseAsTemplate: { exerciseID, customName in
                            Task { await editorViewModel.saveExerciseAsTemplate(exerciseID: exerciseID, customName: customName, store: dataStore) }
                        }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                ScrollView {
                    sidebarPanels(plan: plan)
                        .padding(.bottom, 8)
                }
                .frame(width: min(390, size.width * 0.34))
            }
            .padding(12)
        }
    }

    private func sidebarPanels(plan: TrainingPlan) -> some View {
        VStack(spacing: 12) {
            TrainingLoadSummaryView(summary: loadViewModel.loadSummary(planID: plan.id, store: dataStore))

            TrainingMaterialsSummaryView(
                materials: loadViewModel.materialSummary(planID: plan.id, store: dataStore),
                hints: loadViewModel.organizationHints(materials: loadViewModel.materialSummary(planID: plan.id, store: dataStore))
            )

            TrainingGroupAssignmentView(
                players: dataStore.players,
                groups: groupViewModel.visibleGroups(planID: plan.id, store: dataStore, assignedCoachID: dataStore.trainingFilterAssignedCoachID),
                selectedGroupID: $groupViewModel.selectedGroupID,
                groupName: $groupViewModel.groupName,
                groupGoal: $groupViewModel.groupGoal,
                headCoachUserID: $groupViewModel.headCoachUserID,
                assistantCoachUserID: $groupViewModel.assistantCoachUserID,
                selectedPlayerIDs: $groupViewModel.selectedPlayerIDs,
                onSelectGroup: {
                    groupViewModel.selectedGroupID = $0
                    groupViewModel.load(planID: plan.id, store: dataStore)
                },
                onTogglePlayer: { groupViewModel.togglePlayer($0) },
                onSaveGroup: {
                    Task { await groupViewModel.createOrUpdateGroup(planID: plan.id, store: dataStore) }
                }
            )

            TrainingGroupBriefingView(
                groups: groupViewModel.visibleGroups(planID: plan.id, store: dataStore, assignedCoachID: dataStore.trainingFilterAssignedCoachID),
                selectedGroupID: $groupViewModel.selectedGroupID,
                goal: $groupViewModel.briefingGoal,
                coachingPoints: $groupViewModel.briefingCoachingPoints,
                focusPoints: $groupViewModel.briefingFocusPoints,
                commonMistakes: $groupViewModel.briefingCommonMistakes,
                intensity: $groupViewModel.briefingIntensity,
                onSave: {
                    Task { await groupViewModel.saveBriefing(planID: plan.id, store: dataStore) }
                }
            )

            TrainingTemplateBrowserView(
                templates: editorViewModel.templates(in: dataStore),
                searchText: $editorViewModel.templateSearchText,
                selectedPhaseID: editorViewModel.selectedPhaseID,
                onApplyTemplate: { templateID in
                    guard let phaseID = editorViewModel.selectedPhaseID else { return }
                    Task { await editorViewModel.addTemplate(to: phaseID, templateID: templateID, store: dataStore) }
                }
            )
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Trainingsplanung wird geladen")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedState(_ reason: String) -> some View {
        VStack(spacing: 12) {
            Text("Backend erforderlich")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(reason)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button("Erneut laden") {
                Task { await workspaceViewModel.bootstrap(store: dataStore) }
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Keine Trainingsplanung vorhanden")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Titel eintragen und oben auf \"Neu\" klicken")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    TrainingPlanningWorkspaceView()
        .environmentObject(AppDataStore())
        .frame(width: 1280, height: 760)
}
