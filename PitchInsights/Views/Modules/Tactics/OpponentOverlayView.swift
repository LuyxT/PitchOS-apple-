import SwiftUI

struct OpponentOverlayView: View {
    let mode: OpponentMode
    let markers: [OpponentMarker]
    let size: CGSize
    let isInteractive: Bool
    let onMoveMarker: (Int, TacticalPoint) -> Void
    let onRenameMarker: (Int) -> Void

    @State private var activeMarkerIndex: Int?
    @State private var activeMarkerStart: TacticalPoint?

    var body: some View {
        ZStack {
            if mode != .hidden {
                ForEach(Array(markers.enumerated()), id: \.element.id) { index, marker in
                    markerCircle(marker: marker, isActive: activeMarkerIndex == index)
                        .gesture(dragGesture(for: index, marker: marker))
                        .contextMenu {
                            Button(marker.name.isEmpty ? "Name setzen" : "Name ändern") {
                                onRenameMarker(index)
                            }
                        }
                }
            }
        }
        .allowsHitTesting(isInteractive && mode != .hidden && !markers.isEmpty)
    }

    private func dragGesture(for index: Int, marker: OpponentMarker) -> some Gesture {
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

    private func markerCircle(marker: OpponentMarker, isActive: Bool) -> some View {
        let point = marker.point.cgPoint(in: size)
        let label = marker.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return ZStack(alignment: .top) {
            Circle()
                .fill(Color.red.opacity(mode == .formation ? 0.2 : 0.15))
                .overlay(
                    Circle().stroke(Color.red.opacity(isActive ? 0.55 : 0.35), lineWidth: isActive ? 1.8 : 1.4)
                )
                .frame(width: mode == .formation ? 26 : 22, height: mode == .formation ? 26 : 22)

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
                    .offset(y: 18)
            }
        }
        .position(point)
    }
}
