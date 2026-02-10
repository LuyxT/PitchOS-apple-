import SwiftUI

struct AnalysisDrawingsPanel: View {
    let drawings: [AnalysisDrawing]
    @Binding var selectedDrawingID: UUID?
    let onDelete: (AnalysisDrawing) -> Void
    let onDeleteAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Zeichnungen")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(drawings.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if drawings.isEmpty {
                Text("Keine Zeichnungen")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(drawings) { drawing in
                            row(for: drawing)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Alle löschen", role: .destructive) {
                    Haptics.trigger(.soft)
                    onDeleteAll()
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(drawings.isEmpty)
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

    private func row(for drawing: AnalysisDrawing) -> some View {
        let isSelected = selectedDrawingID == drawing.id

        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(drawing.tool.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(format(drawing.timeSeconds))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
                    .monospacedDigit()
            }
            Spacer()
            if drawing.isTemporary {
                Text("Temporär")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
            }
            Button(role: .destructive) {
                Haptics.trigger(.soft)
                onDelete(drawing)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? AppTheme.primary.opacity(0.16) : AppTheme.surfaceAlt.opacity(0.6))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.trigger(.light)
            selectedDrawingID = drawing.id
        }
        .interactiveSurface(hoverScale: 1.01, pressScale: 0.99, hoverShadowOpacity: 0.1, feedback: .light)
        .contextMenu {
            Button("Löschen", role: .destructive) {
                Haptics.trigger(.soft)
                onDelete(drawing)
            }
        }
    }

    private func format(_ seconds: Double) -> String {
        let total = Int(seconds.rounded(.down))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
