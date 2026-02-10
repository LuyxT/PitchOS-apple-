import SwiftUI

struct TrainingPlanListView: View {
    let plans: [TrainingPlan]
    let selectedPlanID: UUID?
    let onSelect: (UUID?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Trainingspläne")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(plans.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(plans) { plan in
                        Button {
                            onSelect(plan.id)
                        } label: {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plan.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.black)
                                        .lineLimit(1)
                                    Text("\(plan.date.formatted(date: .abbreviated, time: .shortened)) · \(plan.status.title)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if plan.id == selectedPlanID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppTheme.primary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(plan.id == selectedPlanID ? AppTheme.primary.opacity(0.16) : AppTheme.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .stroke(plan.id == selectedPlanID ? AppTheme.primary : AppTheme.border, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
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
