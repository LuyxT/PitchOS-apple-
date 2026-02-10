import SwiftUI
#if os(macOS)
import AppKit
#endif

struct DrawingCanvasLayer: View {
    let drawings: [TacticalDrawing]
    let draftDrawing: TacticalDrawing?
    let drawingsVisible: Bool
    let isDrawingMode: Bool
    let selectedDrawingIDs: Set<UUID>
    let onSelectDrawing: (UUID, Bool) -> Void
    let onDeleteDrawing: (UUID) -> Void
    let onToggleTemporary: (UUID) -> Void
    let onPersistDrawing: (UUID) -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            GeometryReader { proxy in
                ZStack {
                    if drawingsVisible {
                        ForEach(drawings) { drawing in
                            let opacity = drawingOpacity(for: drawing, now: context.date)
                            drawingPath(for: drawing, in: proxy.size)
                                .stroke(
                                    Color(hex: drawing.colorHex).opacity(opacity),
                                    style: StrokeStyle(
                                        lineWidth: selectedDrawingIDs.contains(drawing.id) ? 3 : 2,
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )

                            if drawing.kind == .arrow {
                                arrowHead(for: drawing, in: proxy.size)
                                    .fill(Color(hex: drawing.colorHex).opacity(opacity))
                            }

                            if let bounds = drawingBounds(for: drawing, in: proxy.size) {
                                Color.clear
                                    .frame(width: max(bounds.width, 28), height: max(bounds.height, 28))
                                    .position(x: bounds.midX, y: bounds.midY)
                                    .contentShape(Rectangle())
                                    .allowsHitTesting(!isDrawingMode)
                                    .onTapGesture {
                                        let additive = isAdditiveSelection()
                                        Haptics.trigger(.light)
                                        onSelectDrawing(drawing.id, additive)
                                    }
                                    .contextMenu {
                                        Button("Löschen") {
                                            Haptics.trigger(.soft)
                                            onDeleteDrawing(drawing.id)
                                        }
                                        Button(drawing.isTemporary ? "In Szenario speichern" : "Als temporär markieren") {
                                            Haptics.trigger(.soft)
                                            if drawing.isTemporary {
                                                onPersistDrawing(drawing.id)
                                            } else {
                                                onToggleTemporary(drawing.id)
                                            }
                                        }
                                    }
                            }
                        }
                    }

                    if let draftDrawing {
                        drawingPath(for: draftDrawing, in: proxy.size)
                            .stroke(
                                Color(hex: draftDrawing.colorHex).opacity(0.75),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [5, 4])
                            )
                        if draftDrawing.kind == .arrow {
                            arrowHead(for: draftDrawing, in: proxy.size)
                                .fill(Color(hex: draftDrawing.colorHex).opacity(0.75))
                        }
                    }
                }
                .allowsHitTesting(isDrawingMode || drawingsVisible)
                .animation(AppMotion.settle, value: selectedDrawingIDs)
            }
        }
    }

    private func drawingOpacity(for drawing: TacticalDrawing, now: Date) -> Double {
        guard drawing.isTemporary else { return 1 }
        let duration: TimeInterval = 3
        let elapsed = now.timeIntervalSince(drawing.createdAt)
        let progress = min(max(elapsed / duration, 0), 1)
        return 1 - progress
    }

    private func drawingPath(for drawing: TacticalDrawing, in size: CGSize) -> Path {
        var path = Path()
        switch drawing.kind {
        case .line, .arrow:
            guard drawing.points.count >= 2 else { return path }
            path.move(to: drawing.points[0].cgPoint(in: size))
            path.addLine(to: drawing.points[1].cgPoint(in: size))
        case .mark:
            guard let point = drawing.points.first?.cgPoint(in: size) else { return path }
            let markRect = CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)
            path.addEllipse(in: markRect)
        }
        return path
    }

    private func arrowHead(for drawing: TacticalDrawing, in size: CGSize) -> Path {
        var path = Path()
        guard drawing.points.count >= 2 else { return path }
        let start = drawing.points[0].cgPoint(in: size)
        let end = drawing.points[1].cgPoint(in: size)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength: CGFloat = 12
        let headAngle: CGFloat = .pi / 7

        let point1 = CGPoint(
            x: end.x - headLength * cos(angle - headAngle),
            y: end.y - headLength * sin(angle - headAngle)
        )
        let point2 = CGPoint(
            x: end.x - headLength * cos(angle + headAngle),
            y: end.y - headLength * sin(angle + headAngle)
        )

        path.move(to: end)
        path.addLine(to: point1)
        path.addLine(to: point2)
        path.closeSubpath()
        return path
    }

    private func drawingBounds(for drawing: TacticalDrawing, in size: CGSize) -> CGRect? {
        let points = drawing.points.map { $0.cgPoint(in: size) }
        guard !points.isEmpty else { return nil }
        let xs = points.map { $0.x }
        let ys = points.map { $0.y }
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return nil
        }
        return CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY)).insetBy(dx: -12, dy: -12)
    }

    private func isAdditiveSelection() -> Bool {
        #if os(macOS)
        return NSEvent.modifierFlags.contains(.command)
        #else
        return false
        #endif
    }
}
