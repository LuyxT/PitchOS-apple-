import SwiftUI

struct SquadTacticalSummaryView: View {
    let snapshot: SquadAnalyticsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Taktische Verfügbarkeit")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 10) {
                tacticalCard(title: "Tor", count: snapshot.tacticalLineCounts[.goalkeeper] ?? 0)
                tacticalCard(title: "Defensive", count: snapshot.tacticalLineCounts[.defense] ?? 0)
                tacticalCard(title: "Mittelfeld", count: snapshot.tacticalLineCounts[.midfield] ?? 0)
                tacticalCard(title: "Angriff", count: snapshot.tacticalLineCounts[.attack] ?? 0)
            }
        }
    }

    private func tacticalCard(title: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            Text("\(count)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.surfaceAlt)
        )
    }
}
