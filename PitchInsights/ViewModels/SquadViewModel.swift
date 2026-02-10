import Foundation
import Combine
import SwiftUI
#if os(macOS)
import AppKit
#endif

final class SquadViewModel: ObservableObject {
    @Published var selectedPlayerIDs: Set<UUID> = []
    @Published var sortField: SquadSortField = .number
    @Published var sortAscending = true

    private var lastSelectedID: UUID?

    func apply(players: [Player], filters: SquadFilters) -> [Player] {
        let filtered = players.filter { player in
            matchesSearch(player, text: filters.searchText)
            && (filters.positions.isEmpty || filters.positions.contains(player.primaryPosition))
            && (filters.availability.isEmpty || filters.availability.contains(player.availability))
            && (filters.squadStatus.isEmpty || filters.squadStatus.contains(player.squadStatus))
            && (filters.roles.isEmpty || !filters.roles.isDisjoint(with: player.roles))
            && (filters.groups.isEmpty || !filters.groups.isDisjoint(with: player.groups))
        }

        return sort(players: filtered)
    }

    func sort(players: [Player]) -> [Player] {
        let sorted: [Player]
        switch sortField {
        case .number:
            sorted = players.sorted { $0.number < $1.number }
        case .name:
            sorted = players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .primaryPosition:
            sorted = players.sorted { $0.primaryPosition.rawValue < $1.primaryPosition.rawValue }
        case .availability:
            sorted = players.sorted { $0.availability.rawValue < $1.availability.rawValue }
        case .squadStatus:
            sorted = players.sorted { $0.squadStatus.rawValue < $1.squadStatus.rawValue }
        }

        return sortAscending ? sorted : sorted.reversed()
    }

    func toggleSort(_ field: SquadSortField) {
        if sortField == field {
            sortAscending.toggle()
        } else {
            sortField = field
            sortAscending = true
        }
    }

    func select(playerID: UUID, orderedPlayers: [Player]) {
        let modifiers = currentModifierFlags()
        let ids = orderedPlayers.map { $0.id }
        guard let tappedIndex = ids.firstIndex(of: playerID) else { return }

        if modifiers.contains(.command) {
            if selectedPlayerIDs.contains(playerID) {
                selectedPlayerIDs.remove(playerID)
            } else {
                selectedPlayerIDs.insert(playerID)
            }
            lastSelectedID = playerID
            return
        }

        if modifiers.contains(.shift), let lastSelectedID, let lastIndex = ids.firstIndex(of: lastSelectedID) {
            let range = min(lastIndex, tappedIndex)...max(lastIndex, tappedIndex)
            selectedPlayerIDs = Set(range.compactMap { ids[$0] })
            return
        }

        selectedPlayerIDs = [playerID]
        lastSelectedID = playerID
    }

    #if os(macOS)
    func moveSelection(direction: MoveCommandDirection, orderedPlayers: [Player]) {
        guard !orderedPlayers.isEmpty else { return }
        let ids = orderedPlayers.map { $0.id }

        guard let currentID = selectedPlayerIDs.first, let currentIndex = ids.firstIndex(of: currentID) else {
            selectedPlayerIDs = [ids[0]]
            lastSelectedID = ids[0]
            return
        }

        let nextIndex: Int
        switch direction {
        case .up, .left:
            nextIndex = max(0, currentIndex - 1)
        case .down, .right:
            nextIndex = min(ids.count - 1, currentIndex + 1)
        default:
            return
        }

        selectedPlayerIDs = [ids[nextIndex]]
        lastSelectedID = ids[nextIndex]
    }
    #endif

    func selectedPlayers(from players: [Player]) -> [Player] {
        players.filter { selectedPlayerIDs.contains($0.id) }
    }

    func selectedPlayer(from players: [Player]) -> Player? {
        guard let id = selectedPlayerIDs.first else { return nil }
        return players.first { $0.id == id }
    }

    private func matchesSearch(_ player: Player, text: String) -> Bool {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let normalized = query.lowercased()

        return player.name.lowercased().contains(normalized)
            || player.primaryPosition.rawValue.lowercased().contains(normalized)
            || player.roles.joined(separator: " ").lowercased().contains(normalized)
            || player.groups.joined(separator: " ").lowercased().contains(normalized)
    }

    #if os(macOS)
    private func currentModifierFlags() -> NSEvent.ModifierFlags {
        NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
    }
    #else
    private func currentModifierFlags() -> EventModifiers {
        []
    }
    #endif
}
