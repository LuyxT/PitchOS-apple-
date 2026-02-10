import SwiftUI

struct AnalysisMarkersPanel: View {
    let markers: [AnalysisMarker]
    let categories: [AnalysisMarkerCategory]
    let players: [Player]
    @Binding var selectedMarkerID: UUID?
    @Binding var selectedCategoryFilters: Set<UUID>
    @Binding var selectedPlayerFilters: Set<UUID>
    let highlightMarkerID: UUID?
    let onSeek: (AnalysisMarker) -> Void
    let onDelete: (AnalysisMarker) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Marker")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(markers.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            HStack(spacing: 8) {
                Menu("Kategorie") {
                    ForEach(categories) { category in
                        Button {
                            Haptics.trigger(.soft)
                            if selectedCategoryFilters.contains(category.id) {
                                selectedCategoryFilters.remove(category.id)
                            } else {
                                selectedCategoryFilters.insert(category.id)
                            }
                        } label: {
                            if selectedCategoryFilters.contains(category.id) {
                                Label(category.name, systemImage: "checkmark")
                            } else {
                                Text(category.name)
                            }
                        }
                    }
                }

                Menu("Spieler") {
                    ForEach(players) { player in
                        Button {
                            Haptics.trigger(.soft)
                            if selectedPlayerFilters.contains(player.id) {
                                selectedPlayerFilters.remove(player.id)
                            } else {
                                selectedPlayerFilters.insert(player.id)
                            }
                        } label: {
                            if selectedPlayerFilters.contains(player.id) {
                                Label(player.name, systemImage: "checkmark")
                            } else {
                                Text(player.name)
                            }
                        }
                    }
                }

                Button("Reset") {
                    Haptics.trigger(.soft)
                    selectedCategoryFilters.removeAll()
                    selectedPlayerFilters.removeAll()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            }
            .font(.system(size: 12, weight: .medium))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(markers) { marker in
                        markerRow(marker)
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

    private func markerRow(_ marker: AnalysisMarker) -> some View {
        let isSelected = selectedMarkerID == marker.id
        let isHighlighted = highlightMarkerID == marker.id
        let categoryName = categories.first(where: { $0.id == marker.categoryID })?.name ?? "Allgemein"
        let playerName = players.first(where: { $0.id == marker.playerID })?.name

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(format(marker.timeSeconds))
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.textPrimary)
                Text(categoryName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.primary)
                Spacer()
                if marker.syncState == .syncFailed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
            }

            if !marker.comment.isEmpty {
                Text(marker.comment)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
            }

            if let playerName {
                Text(playerName)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? AppTheme.primary.opacity(0.16) : AppTheme.surfaceAlt.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isHighlighted ? AppTheme.primary.opacity(0.6) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isHighlighted ? 1.015 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.trigger(.light)
            selectedMarkerID = marker.id
            onSeek(marker)
        }
        .interactiveSurface(hoverScale: 1.01, pressScale: 0.99, hoverShadowOpacity: 0.1, feedback: .light)
        .animation(AppMotion.settle, value: highlightMarkerID)
        .contextMenu {
            Button("Anspringen") {
                Haptics.trigger(.light)
                onSeek(marker)
            }
            Button("Löschen", role: .destructive) {
                Haptics.trigger(.soft)
                onDelete(marker)
            }
        }
    }

    private func format(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
