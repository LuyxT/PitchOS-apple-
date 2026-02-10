import SwiftUI

struct AnalysisDrawingOverlay: View {
    let drawings: [AnalysisDrawing]
    let draftPoints: [AnalysisPoint]
    let draftTool: AnalysisDrawingTool
    let isDrawingEnabled: Bool
    let areDrawingsVisible: Bool
    let onBegin: (CGPoint, CGSize) -> Void
    let onChange: (CGPoint, CGSize) -> Void
    let onEnd: (CGPoint, CGSize) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if areDrawingsVisible {
                    Canvas { context, size in
                        for drawing in drawings {
                            render(drawing: drawing, in: size, context: &context)
                        }
                        if draftPoints.count >= 2 {
                            renderDraft(in: size, context: &context)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(drawingGesture(in: proxy.size))
        }
        .allowsHitTesting(isDrawingEnabled)
    }

    private func drawingGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if draftPoints.isEmpty {
                    Haptics.trigger(.soft)
                    onBegin(value.startLocation, size)
                }
                onChange(value.location, size)
            }
            .onEnded { value in
                Haptics.trigger(.light)
                onEnd(value.location, size)
            }
    }

    private func render(drawing: AnalysisDrawing, in size: CGSize, context: inout GraphicsContext) {
        guard drawing.points.count >= 2 else { return }
        let color = Color(hex: drawing.colorHex)
        var path = Path()

        switch drawing.tool {
        case .line:
            path.move(to: point(for: drawing.points[0], in: size))
            path.addLine(to: point(for: drawing.points[1], in: size))
            context.stroke(path, with: .color(color), lineWidth: 2)
        case .arrow:
            let start = point(for: drawing.points[0], in: size)
            let end = point(for: drawing.points[1], in: size)
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(path, with: .color(color), lineWidth: 2)

            let headLength: CGFloat = 14
            let angle = atan2(end.y - start.y, end.x - start.x)
            let left = CGPoint(
                x: end.x - headLength * cos(angle - .pi / 6),
                y: end.y - headLength * sin(angle - .pi / 6)
            )
            let right = CGPoint(
                x: end.x - headLength * cos(angle + .pi / 6),
                y: end.y - headLength * sin(angle + .pi / 6)
            )
            var head = Path()
            head.move(to: end)
            head.addLine(to: left)
            head.move(to: end)
            head.addLine(to: right)
            context.stroke(head, with: .color(color), lineWidth: 2)
        case .circle:
            let start = point(for: drawing.points[0], in: size)
            let end = point(for: drawing.points[1], in: size)
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            path.addEllipse(in: rect)
            context.stroke(path, with: .color(color), lineWidth: 2)
        case .rectangle:
            let start = point(for: drawing.points[0], in: size)
            let end = point(for: drawing.points[1], in: size)
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            path.addRect(rect)
            context.stroke(path, with: .color(color), lineWidth: 2)
        }
    }

    private func renderDraft(in size: CGSize, context: inout GraphicsContext) {
        let drawing = AnalysisDrawing(
            sessionID: UUID(),
            timeSeconds: 0,
            tool: draftTool,
            points: draftPoints,
            colorHex: AppTheme.primary.hexString,
            isTemporary: false
        )
        render(drawing: drawing, in: size, context: &context)
    }

    private func point(for normalized: AnalysisPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
    }
}
