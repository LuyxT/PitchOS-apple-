import SwiftUI

struct TrainingLoadSummaryView: View {
    let summary: TrainingLoadSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Belastungsübersicht")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 8) {
                metricCard(title: "Gesamtzeit", value: "\(summary.totalMinutes) min")
                metricCard(title: "Load", value: "\(summary.loadScore)")
                metricCard(title: "Hoch", value: "\(summary.highIntensityMinutes) min")
            }

            if summary.warningConsecutiveHighLoad {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                    Text("Mehrere intensive Tage hintereinander erkannt")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.black)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.orange.opacity(0.2))
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

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.surfaceAlt.opacity(0.45))
        )
    }
}
