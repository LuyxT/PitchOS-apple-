import SwiftUI

struct SquadAnalyticsPanel: View {
    let snapshot: SquadAnalyticsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kader-Analyse")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Positionsverteilung")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach(PositionGroup.allCases) { group in
                    barRow(
                        title: group.rawValue,
                        value: snapshot.positionCounts[group] ?? 0,
                        color: AppTheme.primary
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Fitness")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                ForEach(AvailabilityStatus.allCases) { state in
                    barRow(
                        title: state.rawValue,
                        value: snapshot.availabilityCounts[state] ?? 0,
                        color: color(for: state)
                    )
                }
            }

            SquadTacticalSummaryView(snapshot: snapshot)

            Spacer(minLength: 0)
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

    private func barRow(title: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(value)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            GeometryReader { proxy in
                let width = min(proxy.size.width, max(0, CGFloat(value) * 20))
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.surfaceAlt)
                    Capsule().fill(color.opacity(0.7)).frame(width: width)
                }
            }
            .frame(height: 8)
        }
    }

    private func color(for state: AvailabilityStatus) -> Color {
        switch state {
        case .fit:
            return AppTheme.primary
        case .limited:
            return .orange
        case .unavailable:
            return .red
        }
    }
}
