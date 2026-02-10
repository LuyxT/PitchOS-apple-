import Foundation
import Combine

@MainActor
final class TacticsDrawingViewModel: ObservableObject {
    @Published var selectedTool: TacticalDrawingKind = .arrow
    @Published var isTemporary = false
    @Published var draftDrawing: TacticalDrawing?

    private var startPoint: TacticalPoint?

    func begin(at point: TacticalPoint) {
        startPoint = point
        draftDrawing = TacticalDrawing(
            kind: selectedTool,
            points: [point],
            colorHex: colorHex(for: selectedTool),
            isTemporary: isTemporary
        )
    }

    func update(to point: TacticalPoint) {
        guard var draftDrawing else { return }

        switch selectedTool {
        case .mark:
            draftDrawing.points = [point]
        case .line, .arrow:
            let start = startPoint ?? point
            draftDrawing.points = [start, point]
        }
        self.draftDrawing = draftDrawing
    }

    func finish() -> TacticalDrawing? {
        defer { cancel() }
        guard let draftDrawing else { return nil }

        switch draftDrawing.kind {
        case .mark:
            return draftDrawing.points.count == 1 ? draftDrawing : nil
        case .line, .arrow:
            return draftDrawing.points.count >= 2 ? draftDrawing : nil
        }
    }

    func cancel() {
        draftDrawing = nil
        startPoint = nil
    }

    private func colorHex(for kind: TacticalDrawingKind) -> String {
        switch kind {
        case .line:
            return "#10B981"
        case .arrow:
            return "#0EA5E9"
        case .mark:
            return "#F59E0B"
        }
    }
}
