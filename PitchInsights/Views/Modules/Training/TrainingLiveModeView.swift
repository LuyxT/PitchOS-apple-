import SwiftUI

struct TrainingLiveModeView: View {
    let plan: TrainingPlan
    let phases: [TrainingPhase]
    let exercisesForPhase: (UUID) -> [TrainingExercise]
    let deviations: [TrainingLiveDeviation]
    @ObservedObject var viewModel: TrainingLiveViewModel

    let onStartLive: () -> Void
    let onTogglePhaseCompletion: (TrainingPhase) -> Void
    let onChangeExerciseDuration: (TrainingExercise, Int) -> Void
    let onToggleExerciseSkip: (TrainingExercise) -> Void
    let onExtendExercise: (TrainingExercise, Int) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                ForEach(phases) { phase in
                    phaseCard(phase)
                }

                deviationCard
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Live-Training")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.black)
                Text(plan.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Button("Live starten", action: onStartLive)
                .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }

    private func phaseCard(_ phase: TrainingPhase) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    onTogglePhaseCompletion(phase)
                } label: {
                    Image(systemName: phase.isCompletedLive ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(phase.isCompletedLive ? AppTheme.primary : AppTheme.textSecondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black)
                    Text("\(phase.durationMinutes) min · \(phase.intensity.title)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Text(phase.goal.isEmpty ? "Kein Ziel" : phase.goal)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            ForEach(exercisesForPhase(phase.id)) { exercise in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.black)
                        Text(exercise.description.isEmpty ? "Ohne Beschreibung" : exercise.description)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()

                    Stepper(
                        "\(viewModel.actualMinutesByExercise[exercise.id] ?? exercise.durationMinutes) min",
                        value: Binding(
                            get: { viewModel.actualMinutesByExercise[exercise.id] ?? exercise.durationMinutes },
                            set: { onChangeExerciseDuration(exercise, $0) }
                        ),
                        in: 1...240
                    )
                    .frame(width: 150)

                    Button {
                        onExtendExercise(exercise, 5)
                    } label: {
                        Label("+5", systemImage: "plus")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button {
                        onExtendExercise(exercise, -5)
                    } label: {
                        Label("-5", systemImage: "minus")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button {
                        onToggleExerciseSkip(exercise)
                    } label: {
                        Text(viewModel.skippedExercises.contains(exercise.id) ? "Aktiv" : "Skip")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(viewModel.skippedExercises.contains(exercise.id) ? Color.orange.opacity(0.15) : AppTheme.surfaceAlt.opacity(0.42))
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }

    private var deviationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Abweichungsprotokoll")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black)

            if deviations.isEmpty {
                Text("Noch keine Abweichungen")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            ForEach(deviations.sorted { $0.timestamp > $1.timestamp }) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(item.kind.title): \(item.plannedValue) → \(item.actualValue)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.black)
                    if !item.note.isEmpty {
                        Text(item.note)
                            .font(.system(size: 11))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.surfaceAlt.opacity(0.45))
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }
}
