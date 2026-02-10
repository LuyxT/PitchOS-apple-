import Foundation
import SwiftUI
import Combine

@MainActor
final class TacticsViewModel: ObservableObject {
    @Published var activeScenarioID: UUID?
    @Published var selection = TacticsSelection()
    @Published var showInspector = true
    @Published var isRenamePromptVisible = false
    @Published var renameDraft = ""
    private var temporaryDrawingTasks: [UUID: Task<Void, Never>] = [:]

    func bootstrap(with store: AppDataStore) {
        store.ensureDefaultTacticsScenario()
        activeScenarioID = store.activeTacticsScenarioID ?? store.tacticsScenarios.first?.id
        syncActiveScenarioToStore(store)
    }

    func currentScenario(in store: AppDataStore) -> TacticsScenario? {
        guard let id = resolvedScenarioID(in: store) else { return nil }
        return store.tacticsScenarios.first(where: { $0.id == id })
    }

    func currentBoard(in store: AppDataStore) -> TacticsBoardState {
        let id = resolvedScenarioID(in: store) ?? store.createScenario(name: "Startelf")
        return store.boardState(for: id)
    }

    func setScenario(_ id: UUID, in store: AppDataStore) {
        activeScenarioID = id
        selection = TacticsSelection()
        syncActiveScenarioToStore(store)
    }

    func createScenario(in store: AppDataStore) {
        let id = store.createScenario(name: "Neues Szenario")
        activeScenarioID = id
        selection = TacticsSelection()
        syncActiveScenarioToStore(store)
    }

    func duplicateScenario(in store: AppDataStore) {
        guard let id = resolvedScenarioID(in: store),
              let duplicatedID = store.duplicateScenario(id: id) else { return }
        activeScenarioID = duplicatedID
        selection = TacticsSelection()
        syncActiveScenarioToStore(store)
    }

    func deleteScenario(in store: AppDataStore) {
        guard let id = resolvedScenarioID(in: store) else { return }
        store.deleteScenario(id: id)
        activeScenarioID = store.activeTacticsScenarioID ?? store.tacticsScenarios.first?.id
        selection = TacticsSelection()
        syncActiveScenarioToStore(store)
    }

    func beginRenamePrompt(in store: AppDataStore) {
        guard let scenario = currentScenario(in: store) else { return }
        renameDraft = scenario.name
        isRenamePromptVisible = true
    }

    func commitRename(in store: AppDataStore) {
        guard let id = resolvedScenarioID(in: store) else { return }
        store.renameScenario(id: id, name: renameDraft)
        isRenamePromptVisible = false
    }

    func resetLayout(in store: AppDataStore) {
        guard let id = resolvedScenarioID(in: store) else { return }
        store.resetScenarioLayout(id: id)
        selection = TacticsSelection()
    }

    func placements(in store: AppDataStore) -> [TacticalPlacement] {
        currentBoard(in: store).placements
    }

    func benchPlayers(in store: AppDataStore) -> [Player] {
        let board = currentBoard(in: store)
        let placedIDs = Set(board.placements.map { $0.playerID })
        let excludedIDs = Set(board.excludedPlayerIDs)
        let benchIDs = Set(board.benchPlayerIDs)
        return store.players
            .filter { !placedIDs.contains($0.id) && !excludedIDs.contains($0.id) }
            .sorted { lhs, rhs in
                let lhsIsBench = benchIDs.contains(lhs.id)
                let rhsIsBench = benchIDs.contains(rhs.id)
                if lhsIsBench != rhsIsBench {
                    return lhsIsBench
                }
                return lhs.number < rhs.number
            }
    }

    func excludedPlayers(in store: AppDataStore) -> [Player] {
        let excluded = Set(currentBoard(in: store).excludedPlayerIDs)
        return store.players.filter { excluded.contains($0.id) }.sorted { $0.number < $1.number }
    }

    func player(for id: UUID, in store: AppDataStore) -> Player? {
        store.player(with: id)
    }

    func dropPlayerOnField(playerID: UUID, at point: TacticalPoint, in store: AppDataStore) {
        var board = currentBoard(in: store)
        if let index = board.placements.firstIndex(where: { $0.playerID == playerID }) {
            board.placements[index].point = point
        } else {
            let resolvedPoint = resolvePlacementPoint(
                desired: point,
                existing: board.placements.map(\.point)
            )
            let role = defaultRole(for: player(for: playerID, in: store))
            board.placements.append(
                TacticalPlacement(playerID: playerID, point: resolvedPoint, role: role)
            )
        }
        board.benchPlayerIDs.removeAll { $0 == playerID }
        board.excludedPlayerIDs.removeAll { $0 == playerID }
        save(board: board, in: store)
    }

    func sendPlayerToBench(playerID: UUID, in store: AppDataStore) {
        var board = currentBoard(in: store)
        board.placements.removeAll { $0.playerID == playerID }
        board.excludedPlayerIDs.removeAll { $0 == playerID }
        if !board.benchPlayerIDs.contains(playerID) {
            board.benchPlayerIDs.append(playerID)
        }
        save(board: board, in: store)
    }

    func removeFromLineup(playerID: UUID, in store: AppDataStore) {
        var board = currentBoard(in: store)
        board.placements.removeAll { $0.playerID == playerID }
        if !board.benchPlayerIDs.contains(playerID) {
            board.benchPlayerIDs.append(playerID)
        }
        save(board: board, in: store)
    }

    func toggleExcluded(playerID: UUID, in store: AppDataStore) {
        var board = currentBoard(in: store)
        if board.excludedPlayerIDs.contains(playerID) {
            board.excludedPlayerIDs.removeAll { $0 == playerID }
            if !board.benchPlayerIDs.contains(playerID) {
                board.benchPlayerIDs.append(playerID)
            }
        } else {
            board.excludedPlayerIDs.append(playerID)
            board.placements.removeAll { $0.playerID == playerID }
            board.benchPlayerIDs.removeAll { $0 == playerID }
        }
        save(board: board, in: store)
    }

    func updateRole(playerID: UUID, roleName: String, in store: AppDataStore) {
        let trimmed = roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var board = currentBoard(in: store)
        guard let index = board.placements.firstIndex(where: { $0.playerID == playerID }) else { return }
        board.placements[index].role = TacticalRole(name: trimmed)
        save(board: board, in: store)
    }

    func updateZone(playerID: UUID, zone: TacticalZone?, in store: AppDataStore) {
        var board = currentBoard(in: store)
        guard let index = board.placements.firstIndex(where: { $0.playerID == playerID }) else { return }
        board.placements[index].zone = zone
        save(board: board, in: store)
    }

    func toggleShowOpponent(in store: AppDataStore) {
        mutateScenario(in: store) { scenario in
            scenario.showOpponent.toggle()
            if !scenario.showOpponent {
                var board = store.boardState(for: scenario.id)
                board.opponentMode = .hidden
                store.saveBoardState(board)
            } else {
                var board = store.boardState(for: scenario.id)
                if board.opponentMode == .hidden {
                    board.opponentMode = .markers
                }
                store.saveBoardState(board)
            }
        }
    }

    func setOpponentMode(_ mode: OpponentMode, in store: AppDataStore) {
        var board = currentBoard(in: store)
        board.opponentMode = mode
        save(board: board, in: store)
        mutateScenario(in: store) { scenario in
            scenario.showOpponent = mode != .hidden
        }
    }

    func moveOpponentMarker(at index: Int, to point: TacticalPoint, in store: AppDataStore) {
        var board = currentBoard(in: store)
        if board.opponentMarkers.count != 11 {
            board.opponentMarkers = OpponentMarker.defaultLine()
        }
        guard board.opponentMarkers.indices.contains(index) else { return }
        board.opponentMarkers[index].point = point
        save(board: board, in: store)
    }

    func updateOpponentMarkerName(at index: Int, name: String, in store: AppDataStore) {
        var board = currentBoard(in: store)
        guard board.opponentMarkers.indices.contains(index) else { return }
        board.opponentMarkers[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        save(board: board, in: store)
    }

    func addNeutralMarker(in store: AppDataStore) {
        var board = currentBoard(in: store)
        let index = board.neutralMarkers.count
        let row = index / 4
        let column = index % 4
        let x = min(0.84, 0.18 + Double(column) * 0.14)
        let y = min(0.84, 0.2 + Double(row) * 0.14)
        board.neutralMarkers.append(
            TacticalNeutralMarker(
                point: TacticalPoint(x: x, y: y),
                name: "Kreis \(index + 1)"
            )
        )
        save(board: board, in: store)
    }

    func moveNeutralMarker(at index: Int, to point: TacticalPoint, in store: AppDataStore) {
        var board = currentBoard(in: store)
        guard board.neutralMarkers.indices.contains(index) else { return }
        board.neutralMarkers[index].point = point
        save(board: board, in: store)
    }

    func updateNeutralMarkerName(id: UUID, name: String, in store: AppDataStore) {
        var board = currentBoard(in: store)
        guard let index = board.neutralMarkers.firstIndex(where: { $0.id == id }) else { return }
        board.neutralMarkers[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        save(board: board, in: store)
    }

    func deleteNeutralMarker(id: UUID, in store: AppDataStore) {
        var board = currentBoard(in: store)
        board.neutralMarkers.removeAll { $0.id == id }
        save(board: board, in: store)
    }

    func toggleShowZones(in store: AppDataStore) {
        mutateScenario(in: store) { scenario in
            scenario.showZones.toggle()
        }
    }

    func toggleShowLines(in store: AppDataStore) {
        mutateScenario(in: store) { scenario in
            scenario.showLines.toggle()
        }
    }

    func toggleDrawingsVisible(in store: AppDataStore) {
        mutateScenario(in: store) { scenario in
            scenario.drawingsVisible.toggle()
        }
    }

    func addDrawing(_ drawing: TacticalDrawing, in store: AppDataStore) {
        var board = currentBoard(in: store)
        board.drawings.append(drawing)
        save(board: board, in: store)
        if drawing.isTemporary {
            scheduleTemporaryDrawingRemoval(drawingID: drawing.id, scenarioID: board.scenarioID, in: store)
        }
    }

    func deleteDrawing(id: UUID, in store: AppDataStore) {
        cancelTemporaryDrawingRemoval(for: id)
        var board = currentBoard(in: store)
        board.drawings.removeAll { $0.id == id }
        save(board: board, in: store)
        selection.drawingIDs.remove(id)
    }

    func toggleDrawingTemporary(id: UUID, in store: AppDataStore) {
        var board = currentBoard(in: store)
        guard let index = board.drawings.firstIndex(where: { $0.id == id }) else { return }
        board.drawings[index].isTemporary.toggle()
        if board.drawings[index].isTemporary {
            board.drawings[index].createdAt = Date()
            scheduleTemporaryDrawingRemoval(drawingID: id, scenarioID: board.scenarioID, in: store)
        } else {
            cancelTemporaryDrawingRemoval(for: id)
        }
        save(board: board, in: store)
    }

    func persistTemporaryDrawing(id: UUID, in store: AppDataStore) {
        cancelTemporaryDrawingRemoval(for: id)
        var board = currentBoard(in: store)
        guard let index = board.drawings.firstIndex(where: { $0.id == id }) else { return }
        board.drawings[index].isTemporary = false
        save(board: board, in: store)
    }

    func deleteSelection(in store: AppDataStore) {
        var board = currentBoard(in: store)
        for playerID in selection.playerIDs {
            board.placements.removeAll { $0.playerID == playerID }
            if !board.benchPlayerIDs.contains(playerID) {
                board.benchPlayerIDs.append(playerID)
            }
        }
        for drawingID in selection.drawingIDs {
            cancelTemporaryDrawingRemoval(for: drawingID)
            board.drawings.removeAll { $0.id == drawingID }
        }
        save(board: board, in: store)
        selection = TacticsSelection()
    }

    #if os(macOS)
    func nudgeSelection(direction: MoveCommandDirection, in store: AppDataStore) {
        guard let playerID = selection.playerIDs.first else { return }
        var board = currentBoard(in: store)
        guard let index = board.placements.firstIndex(where: { $0.playerID == playerID }) else { return }
        var point = board.placements[index].point
        let step = 0.01
        switch direction {
        case .up:
            point.y -= step
        case .down:
            point.y += step
        case .left:
            point.x -= step
        case .right:
            point.x += step
        @unknown default:
            break
        }
        board.placements[index].point = TacticalPoint(x: point.x, y: point.y)
        save(board: board, in: store)
    }
    #endif

    func clearSelection() {
        selection = TacticsSelection()
    }

    func selectPlayer(_ playerID: UUID, additive: Bool = false) {
        if additive {
            if selection.playerIDs.contains(playerID) {
                selection.playerIDs.remove(playerID)
            } else {
                selection.playerIDs.insert(playerID)
            }
        } else {
            selection.playerIDs = [playerID]
        }
        selection.drawingIDs.removeAll()
    }

    func selectDrawing(_ drawingID: UUID, additive: Bool = false) {
        if additive {
            if selection.drawingIDs.contains(drawingID) {
                selection.drawingIDs.remove(drawingID)
            } else {
                selection.drawingIDs.insert(drawingID)
            }
        } else {
            selection.drawingIDs = [drawingID]
        }
        selection.playerIDs.removeAll()
    }

    private func save(board: TacticsBoardState, in store: AppDataStore) {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
            store.saveBoardState(board)
        }
    }

    private func scheduleTemporaryDrawingRemoval(drawingID: UUID, scenarioID: UUID, in store: AppDataStore) {
        cancelTemporaryDrawingRemoval(for: drawingID)
        temporaryDrawingTasks[drawingID] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            defer { self.temporaryDrawingTasks.removeValue(forKey: drawingID) }

            var board = store.boardState(for: scenarioID)
            guard let index = board.drawings.firstIndex(where: { $0.id == drawingID }) else { return }
            guard board.drawings[index].isTemporary else { return }

            board.drawings.remove(at: index)
            self.selection.drawingIDs.remove(drawingID)
            self.save(board: board, in: store)
        }
    }

    private func cancelTemporaryDrawingRemoval(for drawingID: UUID) {
        temporaryDrawingTasks[drawingID]?.cancel()
        temporaryDrawingTasks.removeValue(forKey: drawingID)
    }

    private func mutateScenario(in store: AppDataStore, _ transform: (inout TacticsScenario) -> Void) {
        guard let id = resolvedScenarioID(in: store),
              let index = store.tacticsScenarios.firstIndex(where: { $0.id == id }) else { return }
        var scenario = store.tacticsScenarios[index]
        transform(&scenario)
        store.tacticsScenarios[index] = scenario
    }

    private func resolvedScenarioID(in store: AppDataStore) -> UUID? {
        if let activeScenarioID, store.tacticsScenarios.contains(where: { $0.id == activeScenarioID }) {
            return activeScenarioID
        }
        return store.activeTacticsScenarioID ?? store.tacticsScenarios.first?.id
    }

    private func syncActiveScenarioToStore(_ store: AppDataStore) {
        store.activeTacticsScenarioID = activeScenarioID
    }

    private func defaultRole(for player: Player?) -> TacticalRole {
        guard let player else { return TacticalRole(name: "Rolle") }
        switch player.primaryPosition {
        case .tw:
            return TacticalRole(name: "TW")
        case .iv:
            return TacticalRole(name: "IV")
        case .lv:
            return TacticalRole(name: "LV")
        case .rv:
            return TacticalRole(name: "RV")
        case .dm:
            return TacticalRole(name: "6er")
        case .zm:
            return TacticalRole(name: "8er")
        case .om:
            return TacticalRole(name: "10er")
        case .la:
            return TacticalRole(name: "LA")
        case .ra:
            return TacticalRole(name: "RA")
        case .st:
            return TacticalRole(name: "ST")
        }
    }

    // Avoid exact overlap when players are dropped to nearly the same field point.
    private func resolvePlacementPoint(desired: TacticalPoint, existing: [TacticalPoint]) -> TacticalPoint {
        let minDistance = 0.07
        if !hasCollision(desired, existing: existing, threshold: minDistance) {
            return desired
        }

        let offsets: [TacticalPoint] = [
            TacticalPoint(x: desired.x + 0.07, y: desired.y),
            TacticalPoint(x: desired.x - 0.07, y: desired.y),
            TacticalPoint(x: desired.x, y: desired.y + 0.07),
            TacticalPoint(x: desired.x, y: desired.y - 0.07),
            TacticalPoint(x: desired.x + 0.06, y: desired.y + 0.06),
            TacticalPoint(x: desired.x - 0.06, y: desired.y + 0.06),
            TacticalPoint(x: desired.x + 0.06, y: desired.y - 0.06),
            TacticalPoint(x: desired.x - 0.06, y: desired.y - 0.06),
            TacticalPoint(x: desired.x + 0.12, y: desired.y),
            TacticalPoint(x: desired.x - 0.12, y: desired.y),
            TacticalPoint(x: desired.x, y: desired.y + 0.12),
            TacticalPoint(x: desired.x, y: desired.y - 0.12)
        ]

        for candidate in offsets {
            if !hasCollision(candidate, existing: existing, threshold: minDistance) {
                return candidate
            }
        }
        return desired
    }

    private func hasCollision(_ point: TacticalPoint, existing: [TacticalPoint], threshold: Double) -> Bool {
        existing.contains { current in
            let dx = current.x - point.x
            let dy = current.y - point.y
            return (dx * dx + dy * dy).squareRoot() < threshold
        }
    }
}
