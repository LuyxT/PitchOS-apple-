import SwiftUI

struct NeutralMarkerOverlayView: View {
    let markers: [TacticalNeutralMarker]
    let size: CGSize
    let isInteractive: Bool
    let onMoveMarker: (Int, TacticalPoint) -> Void
    let onRenameMarker: (UUID) -> Void
    let onDeleteMarker: (UUID) -> Void

    @State private var activeMarkerIndex: Int?
    @State private var activeMarkerStart: TacticalPoint?

    var body: some View {
        ZStack {
            ForEach(Array(markers.enumerated()), id: \.element.id) { index, marker in
                markerBubble(marker: marker, isActive: activeMarkerIndex == index)
                    .gesture(dragGesture(for: index, marker: marker))
                    .contextMenu {
                        Button(marker.name.isEmpty ? "Name setzen" : "Name ändern") {
                            onRenameMarker(marker.id)
                        }
                        Button("Löschen", role: .destructive) {
                            onDeleteMarker(marker.id)
                        }
                    }
            }
        }
        .allowsHitTesting(isInteractive && !markers.isEmpty)
    }

    private func dragGesture(for index: Int, marker: TacticalNeutralMarker) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if activeMarkerIndex != index {
                    activeMarkerIndex = index
                    activeMarkerStart = marker.point
                }

                guard let index = activeMarkerIndex, let start = activeMarkerStart else { return }
                let dx = Double(value.translation.width / max(size.width, 1))
                let dy = Double(value.translation.height / max(size.height, 1))
                let moved = TacticalPoint(x: start.x + dx, y: start.y + dy)
                onMoveMarker(index, moved)
            }
            .onEnded { _ in
                activeMarkerIndex = nil
                activeMarkerStart = nil
            }
    }

    private func markerBubble(marker: TacticalNeutralMarker, isActive: Bool) -> some View {
        let point = marker.point.cgPoint(in: size)
        let label = marker.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(spacing: 3) {
            Circle()
                .fill(Color.gray.opacity(0.18))
                .overlay(
                    Circle()
                        .stroke(
                            Color.gray.opacity(isActive ? 0.9 : 0.6),
                            lineWidth: isActive ? 2.0 : 1.4
                        )
                )
                .frame(width: 24, height: 24)
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppTheme.surface.opacity(0.94))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            )
                    )
            }
        }
        .position(point)
    }
}
