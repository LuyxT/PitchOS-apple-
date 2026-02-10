import SwiftUI

struct ScenarioStripView: View {
    let scenarios: [TacticsScenario]
    let activeScenarioID: UUID?
    let onSelect: (UUID) -> Void
    let onCreate: () -> Void
    let onDuplicate: (UUID) -> Void
    let onRename: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onReset: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(scenarios) { scenario in
                    scenarioChip(scenario)
                        .contextMenu {
                            Button("Duplizieren") { onDuplicate(scenario.id) }
                            Button("Umbenennen") { onRename(scenario.id) }
                            Button("Zurücksetzen") { onReset(scenario.id) }
                            Divider()
                            Button("Löschen", role: .destructive) { onDelete(scenario.id) }
                        }
                }

                Button {
                    onCreate()
                } label: {
                    Label("Neu", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppTheme.surfaceAlt)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(AppTheme.border, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(AppTheme.surface)
    }

    private func scenarioChip(_ scenario: TacticsScenario) -> some View {
        let isActive = scenario.id == activeScenarioID
        return Button {
            onSelect(scenario.id)
        } label: {
            HStack(spacing: 6) {
                Text(scenario.name)
                    .font(.system(size: 12, weight: .semibold))
                Text(scenario.updatedAt, style: .time)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .foregroundStyle(isActive ? AppTheme.primaryDark : AppTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? AppTheme.primary.opacity(0.16) : AppTheme.surfaceAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isActive ? AppTheme.primary : AppTheme.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
