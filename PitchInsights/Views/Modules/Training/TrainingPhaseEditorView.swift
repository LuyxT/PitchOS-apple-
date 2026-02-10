import SwiftUI

struct TrainingPhaseEditorView: View {
    let plan: TrainingPlan
    let phases: [TrainingPhase]
    @Binding var selectedPhaseID: UUID?
    @Binding var newPhaseType: TrainingPhaseType
    @Binding var newExerciseName: String

    let exercisesForPhase: (UUID) -> [TrainingExercise]

    let onAddPhase: () -> Void
    let onMovePhase: (Int, Int) -> Void
    let onSavePhase: (TrainingPhase) -> Void
    let onDuplicatePhase: (TrainingPhase) -> Void
    let onDeletePhase: (TrainingPhase) -> Void

    let onAddExercise: (UUID) -> Void
    let onMoveExercise: (UUID, Int, Int) -> Void
    let onSaveExercise: (TrainingExercise) -> Void
    let onDuplicateExercise: (UUID, UUID) -> Void
    let onDeleteExercise: (UUID, UUID) -> Void
    let onSaveExerciseAsTemplate: (UUID, String?) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                    TrainingPhaseCard(
                        phase: phase,
                        exercises: exercisesForPhase(phase.id),
                        selected: selectedPhaseID == phase.id,
                        canMoveUp: index > 0,
                        canMoveDown: index < phases.count - 1,
                        newExerciseName: $newExerciseName,
                        onSelect: {
                            selectedPhaseID = phase.id
                        },
                        onMoveUp: {
                            onMovePhase(index, index - 1)
                        },
                        onMoveDown: {
                            onMovePhase(index, index + 1)
                        },
                        onSavePhase: onSavePhase,
                        onDuplicatePhase: onDuplicatePhase,
                        onDeletePhase: onDeletePhase,
                        onAddExercise: { onAddExercise(phase.id) },
                        onMoveExercise: { from, to in
                            onMoveExercise(phase.id, from, to)
                        },
                        onSaveExercise: onSaveExercise,
                        onDuplicateExercise: { exerciseID in
                            onDuplicateExercise(phase.id, exerciseID)
                        },
                        onDeleteExercise: { exerciseID in
                            onDeleteExercise(phase.id, exerciseID)
                        },
                        onSaveExerciseAsTemplate: onSaveExerciseAsTemplate
                    )
                }
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Phasen und Übungen")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            Picker("Neue Phase", selection: $newPhaseType) {
                ForEach(TrainingPhaseType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 170)

            Button("Phase hinzufügen", action: onAddPhase)
                .buttonStyle(SecondaryActionButtonStyle())
        }
    }
}

private struct TrainingPhaseCard: View {
    let phase: TrainingPhase
    let exercises: [TrainingExercise]
    let selected: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    @Binding var newExerciseName: String

    let onSelect: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onSavePhase: (TrainingPhase) -> Void
    let onDuplicatePhase: (TrainingPhase) -> Void
    let onDeletePhase: (TrainingPhase) -> Void
    let onAddExercise: () -> Void
    let onMoveExercise: (Int, Int) -> Void
    let onSaveExercise: (TrainingExercise) -> Void
    let onDuplicateExercise: (UUID) -> Void
    let onDeleteExercise: (UUID) -> Void
    let onSaveExerciseAsTemplate: (UUID, String?) -> Void

    @State private var draft: TrainingPhase

    init(
        phase: TrainingPhase,
        exercises: [TrainingExercise],
        selected: Bool,
        canMoveUp: Bool,
        canMoveDown: Bool,
        newExerciseName: Binding<String>,
        onSelect: @escaping () -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onSavePhase: @escaping (TrainingPhase) -> Void,
        onDuplicatePhase: @escaping (TrainingPhase) -> Void,
        onDeletePhase: @escaping (TrainingPhase) -> Void,
        onAddExercise: @escaping () -> Void,
        onMoveExercise: @escaping (Int, Int) -> Void,
        onSaveExercise: @escaping (TrainingExercise) -> Void,
        onDuplicateExercise: @escaping (UUID) -> Void,
        onDeleteExercise: @escaping (UUID) -> Void,
        onSaveExerciseAsTemplate: @escaping (UUID, String?) -> Void
    ) {
        self.phase = phase
        self.exercises = exercises
        self.selected = selected
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self._newExerciseName = newExerciseName
        self.onSelect = onSelect
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onSavePhase = onSavePhase
        self.onDuplicatePhase = onDuplicatePhase
        self.onDeletePhase = onDeletePhase
        self.onAddExercise = onAddExercise
        self.onMoveExercise = onMoveExercise
        self.onSaveExercise = onSaveExercise
        self.onDuplicateExercise = onDuplicateExercise
        self.onDeleteExercise = onDeleteExercise
        self.onSaveExerciseAsTemplate = onSaveExerciseAsTemplate
        _draft = State(initialValue: phase)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        TextField("Phasenname", text: $draft.title)
                            .textFieldStyle(.roundedBorder)
                        Picker("Typ", selection: $draft.type) {
                            ForEach(TrainingPhaseType.allCases) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 160)
                    }

                    HStack(spacing: 8) {
                        Stepper("\(draft.durationMinutes) min", value: $draft.durationMinutes, in: 1...180)
                            .frame(width: 130)
                        Picker("Intensität", selection: $draft.intensity) {
                            ForEach(TrainingIntensity.allCases) { intensity in
                                Text(intensity.title).tag(intensity)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 240)

                        TextField("Ziel", text: $draft.goal)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField("Beschreibung", text: $draft.description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }

                VStack(spacing: 6) {
                    Button {
                        onMoveUp()
                    } label: {
                        Image(systemName: "arrow.up")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(!canMoveUp)

                    Button {
                        onMoveDown()
                    } label: {
                        Image(systemName: "arrow.down")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(!canMoveDown)
                }
            }

            HStack(spacing: 8) {
                Button("Speichern") {
                    onSavePhase(draft)
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button("Kopieren") {
                    onDuplicatePhase(phase)
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button("Löschen", role: .destructive) {
                    onDeletePhase(phase)
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Spacer()
            }

            TrainingExerciseEditorView(
                phaseID: phase.id,
                exercises: exercises,
                newExerciseName: $newExerciseName,
                onAddExercise: { _ in
                    onAddExercise()
                },
                onMoveExercise: { _, from, to in
                    onMoveExercise(from, to)
                },
                onSaveExercise: onSaveExercise,
                onDuplicateExercise: { _, exerciseID in
                    onDuplicateExercise(exerciseID)
                },
                onDeleteExercise: { _, exerciseID in
                    onDeleteExercise(exerciseID)
                },
                onSaveExerciseAsTemplate: onSaveExerciseAsTemplate
            )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? AppTheme.primary.opacity(0.08) : AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(selected ? AppTheme.primary : AppTheme.border, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onChange(of: phase) { _, updated in
            draft = updated
        }
    }
}
