import SwiftUI

struct TrainingGroupBriefingView: View {
    let groups: [TrainingGroup]
    @Binding var selectedGroupID: UUID?
    @Binding var goal: String
    @Binding var coachingPoints: String
    @Binding var focusPoints: String
    @Binding var commonMistakes: String
    @Binding var intensity: TrainingIntensity

    let onSave: () -> Void

    private var selectedGroupName: String {
        guard let selectedGroupID,
              let group = groups.first(where: { $0.id == selectedGroupID }) else {
            return "Keine Gruppe"
        }
        return group.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Trainer-Briefing")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(selectedGroupName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            TextField("Ziel der Gruppe", text: $goal)
                .textFieldStyle(.roundedBorder)

            TextField("Coaching-Punkte", text: $coachingPoints, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            TextField("Fokus", text: $focusPoints, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            TextField("Typische Fehler", text: $commonMistakes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            Picker("Zielintensität", selection: $intensity) {
                ForEach(TrainingIntensity.allCases) { value in
                    Text(value.title).tag(value)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Spacer()
                Button("Briefing speichern", action: onSave)
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(selectedGroupID == nil)
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
