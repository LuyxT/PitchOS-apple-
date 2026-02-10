import SwiftUI

struct TrainingReportView: View {
    let plan: TrainingPlan
    let players: [Player]
    let groups: [TrainingGroup]
    let availability: [TrainingAvailabilitySnapshot]
    let existingReport: TrainingReport?
    @ObservedObject var viewModel: TrainingReportViewModel

    let onGenerate: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                attendanceCard

                groupFeedbackCard

                playerNotesCard

                if let existingReport {
                    savedReportCard(existingReport)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trainingsbericht")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.black)
                    Text(plan.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Button {
                    onGenerate()
                } label: {
                    if viewModel.isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Bericht speichern")
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(viewModel.isGenerating)
            }

            TextField("Zusammenfassung", text: $viewModel.summary, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
        }
        .padding(12)
        .background(cardBackground)
    }

    private var attendanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Anwesenheit")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black)

            if availability.isEmpty {
                Text("Keine Verfügbarkeitsdaten")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            ForEach(availability) { item in
                let playerName = players.first(where: { $0.id == item.playerID })?.name ?? "Unbekannt"
                HStack {
                    Text(playerName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black)
                    Spacer()
                    Text(attendanceText(item))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(attendanceColor(item))
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
        .background(cardBackground)
    }

    private var groupFeedbackCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rückmeldungen pro Gruppe")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black)

            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.black)
                    TextField("Feedback", text: Binding(
                        get: { viewModel.groupFeedbackByGroup[group.id] ?? "" },
                        set: { viewModel.groupFeedbackByGroup[group.id] = $0 }
                    ), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                }
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private var playerNotesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spielernotizen")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black)

            ForEach(players) { player in
                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(player.number) \(player.name)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.black)
                    TextField("Notiz", text: Binding(
                        get: { viewModel.playerNotesByPlayer[player.id] ?? "" },
                        set: { viewModel.playerNotesByPlayer[player.id] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding(12)
        .background(cardBackground)
    }

    private func savedReportCard(_ report: TrainingReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gespeicherter Bericht")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black)
            Text("Geplant: \(report.plannedTotalMinutes) min · Tatsächlich: \(report.actualTotalMinutes) min")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            Text(report.summary)
                .font(.system(size: 12))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(cardBackground)
    }

    private func attendanceText(_ item: TrainingAvailabilitySnapshot) -> String {
        if item.isAbsent {
            return "Abwesend"
        }
        if item.isLimited {
            return "Eingeschränkt"
        }
        return item.availability.rawValue
    }

    private func attendanceColor(_ item: TrainingAvailabilitySnapshot) -> Color {
        if item.isAbsent {
            return .red
        }
        if item.isLimited {
            return .orange
        }
        return AppTheme.primary
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}
