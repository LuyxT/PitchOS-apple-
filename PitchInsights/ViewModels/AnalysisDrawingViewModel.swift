import SwiftUI
import Combine

final class AnalysisDrawingViewModel: ObservableObject {
    @Published var isDrawingMode = false
    @Published var selectedTool: AnalysisDrawingTool = .line
    @Published var isTemporary = false
    @Published var areDrawingsVisible = true
    @Published var strokeColor: Color = AppTheme.primary
    @Published private(set) var draftPoints: [AnalysisPoint] = []

    private var cleanupTasks: [UUID: Task<Void, Never>] = [:]

    func begin(at location: CGPoint, in size: CGSize) {
        let point = normalizedPoint(from: location, in: size)
        draftPoints = [point]
    }

    func update(at location: CGPoint, in size: CGSize) {
        let point = normalizedPoint(from: location, in: size)

        switch selectedTool {
        case .line, .arrow, .circle, .rectangle:
            if draftPoints.count == 1 {
                draftPoints.append(point)
            } else if draftPoints.count >= 2 {
                draftPoints[1] = point
            }
        }
    }

    func cancelDraft() {
        draftPoints = []
    }

    func finish(sessionID: UUID, timeSeconds: Double) -> AnalysisDrawing? {
        guard draftPoints.count >= 2 else {
            draftPoints = []
            return nil
        }

        let drawing = AnalysisDrawing(
            sessionID: sessionID,
            timeSeconds: timeSeconds,
            tool: selectedTool,
            points: draftPoints,
            colorHex: strokeColor.hexString,
            isTemporary: isTemporary,
            syncState: .synced
        )
        draftPoints = []
        return drawing
    }

    func scheduleTemporaryCleanup(for drawingID: UUID, onExpire: @escaping () -> Void) {
        cleanupTasks[drawingID]?.cancel()
        cleanupTasks[drawingID] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                onExpire()
                self?.cleanupTasks.removeValue(forKey: drawingID)
            }
        }
    }

    func invalidateCleanup(for drawingID: UUID) {
        cleanupTasks[drawingID]?.cancel()
        cleanupTasks.removeValue(forKey: drawingID)
    }

    private func normalizedPoint(from location: CGPoint, in size: CGSize) -> AnalysisPoint {
        guard size.width > 0, size.height > 0 else {
            return AnalysisPoint(x: 0.5, y: 0.5)
        }
        return AnalysisPoint(
            x: location.x / size.width,
            y: location.y / size.height
        )
    }
}
