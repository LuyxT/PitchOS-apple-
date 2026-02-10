import SwiftUI

struct TrainingExerciseEditorView: View {
    let phaseID: UUID
    let exercises: [TrainingExercise]
    @Binding var newExerciseName: String

    let onAddExercise: (UUID) -> Void
    let onMoveExercise: (UUID, Int, Int) -> Void
    let onSaveExercise: (TrainingExercise) -> Void
    let onDuplicateExercise: (UUID, UUID) -> Void
    let onDeleteExercise: (UUID, UUID) -> Void
    let onSaveExerciseAsTemplate: (UUID, String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Übung hinzufügen", text: $newExerciseName)
                    .textFieldStyle(.roundedBorder)
                Button("Hinzufügen") {
                    onAddExercise(phaseID)
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }

            if exercises.isEmpty {
                Text("Keine Übungen in dieser Phase")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.vertical, 6)
            }

            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                TrainingExerciseRow(
                    phaseID: phaseID,
                    exercise: exercise,
                    canMoveUp: index > 0,
                    canMoveDown: index < exercises.count - 1,
                    onMoveUp: { onMoveExercise(phaseID, index, index - 1) },
                    onMoveDown: { onMoveExercise(phaseID, index, index + 1) },
                    onSave: onSaveExercise,
                    onDuplicate: { onDuplicateExercise(phaseID, exercise.id) },
                    onDelete: { onDeleteExercise(phaseID, exercise.id) },
                    onSaveTemplate: { name in onSaveExerciseAsTemplate(exercise.id, name) }
                )
            }
        }
    }
}

private struct TrainingExerciseRow: View {
    let phaseID: UUID
    let exercise: TrainingExercise
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onSave: (TrainingExercise) -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onSaveTemplate: (String?) -> Void

    @State private var draft: TrainingExercise
    @State private var templateName = ""

    init(
        phaseID: UUID,
        exercise: TrainingExercise,
        canMoveUp: Bool,
        canMoveDown: Bool,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void,
        onSave: @escaping (TrainingExercise) -> Void,
        onDuplicate: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onSaveTemplate: @escaping (String?) -> Void
    ) {
        self.phaseID = phaseID
        self.exercise = exercise
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onSave = onSave
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete
        self.onSaveTemplate = onSaveTemplate
        _draft = State(initialValue: exercise)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Name", text: $draft.name)
                    .textFieldStyle(.roundedBorder)
                Picker("", selection: $draft.intensity) {
                    ForEach(TrainingIntensity.allCases) { intensity in
                        Text(intensity.title).tag(intensity)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 110)

                Stepper("\(draft.durationMinutes) min", value: $draft.durationMinutes, in: 1...180)
                    .frame(width: 130)
                Stepper("\(draft.requiredPlayers) Spieler", value: $draft.requiredPlayers, in: 1...30)
                    .frame(width: 150)
            }

            TextField("Beschreibung", text: $draft.description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Material")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Button {
                        draft.materials.append(
                            TrainingMaterialQuantity(kind: .baelle, label: "", quantity: 1)
                        )
                    } label: {
                        Label("Material", systemImage: "plus")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.primary)
                }

                ForEach(Array(draft.materials.enumerated()), id: \.element.id) { index, _ in
                    HStack(spacing: 8) {
                        Picker("", selection: $draft.materials[index].kind) {
                            ForEach(TrainingMaterialKind.allCases) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 120)

                        TextField("Bezeichnung", text: $draft.materials[index].label)
                            .textFieldStyle(.roundedBorder)

                        Stepper("\(draft.materials[index].quantity)", value: $draft.materials[index].quantity, in: 0...100)
                            .frame(width: 80)

                        Button(role: .destructive) {
                            draft.materials.remove(at: index)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 8) {
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

                Button("Duplizieren") {
                    onDuplicate()
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Button("Speichern") {
                    onSave(draft)
                }
                .buttonStyle(PrimaryActionButtonStyle())

                TextField("Vorlagenname", text: $templateName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)

                Button("Als Vorlage") {
                    onSaveTemplate(templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : templateName)
                }
                .buttonStyle(SecondaryActionButtonStyle())

                Spacer()

                Button("Löschen", role: .destructive) {
                    onDelete()
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.surfaceAlt.opacity(0.45))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
        .onChange(of: exercise) { _, updated in
            draft = updated
        }
    }
}
