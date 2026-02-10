import SwiftUI

struct AnalysisClipsPanel: View {
    let clips: [AnalysisClip]
    let players: [Player]
    @Binding var selectedClipID: UUID?
    let onSelect: (AnalysisClip) -> Void
    let onDelete: (AnalysisClip) -> Void
    let onShare: (AnalysisClip) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Clips")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(clips.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(clips) { clip in
                        clipRow(clip)
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

    private func clipRow(_ clip: AnalysisClip) -> some View {
        let isSelected = selectedClipID == clip.id
        let assignedPlayers = players.filter { clip.playerIDs.contains($0.id) }

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(clip.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                if clip.syncState == .syncFailed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                }
            }

            Text("\(format(clip.startSeconds)) - \(format(clip.endSeconds))  |  \(format(clip.duration))")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(AppTheme.textSecondary)
                .monospacedDigit()

            if !assignedPlayers.isEmpty {
                Text(assignedPlayers.map(\.name).joined(separator: ", "))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? AppTheme.primary.opacity(0.16) : AppTheme.surfaceAlt.opacity(0.6))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedClipID = clip.id
            onSelect(clip)
        }
        .contextMenu {
            Button("Öffnen") {
                onSelect(clip)
            }
            Button("Teilen") {
                onShare(clip)
            }
            Button("Löschen", role: .destructive) {
                onDelete(clip)
            }
        }
    }

    private func format(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
