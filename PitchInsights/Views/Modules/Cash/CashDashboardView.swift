import SwiftUI

struct CashDashboardView: View {
    @ObservedObject var viewModel: CashDashboardViewModel
    let summary: CashSummary
    let timelinePoints: [CashTimelinePoint]
    let categoryBreakdown: [CashCategoryBreakdown]
    let topExpense: [CashCategoryBreakdown]
    let topIncome: [CashCategoryBreakdown]
    let goals: [CashGoal]
    let canViewBalance: Bool
    let canManageGoals: Bool
    let onCreateGoal: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                summaryGrid
                chartSection
                categorySection
                goalSection
            }
        }
    }

    private var summaryGrid: some View {
        HStack(spacing: 12) {
            summaryCard(
                title: "Kontostand",
                value: canViewBalance ? currency(summary.currentBalance) : "Verdeckt",
                accent: AppTheme.primaryDark
            )
            summaryCard(
                title: "Einnahmen",
                value: canViewBalance ? currency(summary.totalIncome) : "Verdeckt",
                accent: AppTheme.primaryDark
            )
            summaryCard(
                title: "Ausgaben",
                value: canViewBalance ? currency(summary.totalExpense) : "Verdeckt",
                accent: .red
            )
            summaryCard(
                title: "Prognose",
                value: canViewBalance ? currency(summary.projectedBalance) : "Verdeckt",
                accent: .blue
            )
        }
    }

    private func summaryCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent.opacity(0.9))
                .frame(height: 3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zeitverlauf")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.black)
                    Text(viewModel.rangeDisplay)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.62))
                }
                Spacer()
                HStack(spacing: 8) {
                    Text("Zeitraum")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.black)
                    rangePresetPicker
                }
                HStack(spacing: 8) {
                    Text("Granularität")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.black)
                    granularityPicker
                }
            }

            CashDiagramView(
                timeline: timelinePoints,
                categoryBreakdown: categoryBreakdown,
                granularity: viewModel.granularity
            )
            .frame(height: 280)
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

    private var categorySection: some View {
        HStack(spacing: 12) {
            categoryList(title: "Top Ausgaben", rows: topExpense, color: .red)
            categoryList(title: "Top Einnahmen", rows: topIncome, color: AppTheme.primaryDark)
        }
    }

    private func categoryList(title: String, rows: [CashCategoryBreakdown], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            ForEach(rows) { row in
                HStack {
                    Text(row.categoryName)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text(currency(row.amount))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(color)
                }
            }
            if rows.isEmpty {
                Text("Keine Daten")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Kassenziele")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black)
                Spacer()
                if canManageGoals {
                    Button {
                        onCreateGoal()
                    } label: {
                        Label("Ziel hinzufügen", systemImage: "plus")
                            .foregroundStyle(Color.black)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }
            }
            ForEach(goals.prefix(3)) { goal in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(goal.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.black)
                        Spacer()
                        Text("\(Int(goal.progressRatio * 100)) %")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.black)
                    }
                    ProgressView(value: goal.progressRatio)
                        .tint(AppTheme.primary)
                }
            }
            if goals.isEmpty {
                Text("Keine Ziele hinterlegt")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.black.opacity(0.66))
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

    private var rangePresetPicker: some View {
        HStack(spacing: 6) {
            ForEach(CashDashboardViewModel.RangePreset.allCases) { preset in
                if viewModel.rangePreset == preset {
                    Button(preset.rawValue) {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            viewModel.rangePreset = preset
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .font(.system(size: 11, weight: .semibold))
                } else {
                    Button(preset.rawValue) {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            viewModel.rangePreset = preset
                        }
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .font(.system(size: 11, weight: .semibold))
                }
            }
        }
    }

    private var granularityPicker: some View {
        HStack(spacing: 6) {
            ForEach(CashTimelineGranularity.allCases) { item in
                if viewModel.granularity == item {
                    Button(item.rawValue) {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            viewModel.granularity = item
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .font(.system(size: 11, weight: .semibold))
                } else {
                    Button(item.rawValue) {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            viewModel.granularity = item
                        }
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .font(.system(size: 11, weight: .semibold))
                }
            }
        }
    }

    private func currency(_ value: Double) -> String {
        Self.currencyFormatter.string(from: NSNumber(value: value)) ?? "0 €"
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
}
