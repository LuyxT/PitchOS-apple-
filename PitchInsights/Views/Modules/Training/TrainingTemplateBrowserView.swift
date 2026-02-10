import SwiftUI

struct TrainingTemplateBrowserView: View {
    let templates: [TrainingExerciseTemplate]
    @Binding var searchText: String
    let selectedPhaseID: UUID?
    let onApplyTemplate: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Übungsvorlagen")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(templates.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            TextField("Vorlagen suchen", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(templates) { template in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.black)
                                Text("\(template.defaultDuration) min · \(template.defaultIntensity.title)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Button("Übernehmen") {
                                onApplyTemplate(template.id)
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                            .disabled(selectedPhaseID == nil)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppTheme.surfaceAlt.opacity(0.45))
                        )
                    }
                }
            }
            .frame(maxHeight: 200)
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
