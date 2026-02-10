import SwiftUI

struct CashGoalsView: View {
    let goals: [CashGoal]
    let canEdit: Bool
    let onCreate: () -> Void
    let onEdit: (CashGoal) -> Void
    let onDelete: (CashGoal) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                HStack {
                    Text("Kassenziele")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.black)
                    Spacer()
                    if canEdit {
                        Button {
                            onCreate()
                        } label: {
                            Label("Ziel hinzufügen", systemImage: "plus")
                                .foregroundStyle(Color.black)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    }
                }

                if goals.isEmpty {
                    EmptyStateView(
                        title: "Keine Kassenziele",
                        subtitle: "Lege ein Ziel an, um Fortschritt und Finanzierung zu steuern."
                    )
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                    )
                } else {
                    ForEach(goals) { goal in
                        goalCard(goal)
                    }
                }
            }
        }
        .foregroundStyle(Color.black)
        .environment(\.colorScheme, .light)
    }

    private func goalCard(_ goal: CashGoal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.black)
                    Text("\(Self.dateFormatter.string(from: goal.startDate)) – \(Self.dateFormatter.string(from: goal.endDate))")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.black.opacity(0.66))
                }
                Spacer()
                if canEdit {
                    Menu {
                        Button("Bearbeiten") { onEdit(goal) }
                        Button("Löschen", role: .destructive) { onDelete(goal) }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.black)
                    }
                    #if os(macOS)
                    .menuStyle(.borderlessButton)
                    #endif
                }
            }

            ProgressView(value: goal.progressRatio) {
                HStack {
                    Text("Fortschritt")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.66))
                    Spacer()
                    Text("\(Int(goal.progressRatio * 100)) %")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.black)
                }
            }
            .tint(AppTheme.primary)

            HStack(spacing: 14) {
                infoChip("Aktuell", value: Self.currencyFormatter.string(from: NSNumber(value: goal.currentProgress)) ?? "0 €")
                infoChip("Ziel", value: Self.currencyFormatter.string(from: NSNumber(value: goal.targetAmount)) ?? "0 €")
                infoChip("Fehlt", value: Self.currencyFormatter.string(from: NSNumber(value: max(goal.targetAmount - goal.currentProgress, 0))) ?? "0 €")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }

    private func infoChip(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.66))
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.black)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.surfaceAlt.opacity(0.55))
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
}

private struct EmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Color.black.opacity(0.66))
                .multilineTextAlignment(.center)
        }
    }
}
