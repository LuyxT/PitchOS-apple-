import Foundation
import Combine

@MainActor
final class SquadFilterViewModel: ObservableObject {
    @Published var filters = SquadFilters()
    @Published var isAnalysisVisible = true

    var availableRoles: [String] = []
    var availableGroups: [String] = []

    func refreshOptions(players: [Player]) {
        availableRoles = Array(Set(players.flatMap { $0.roles })).sorted()
        availableGroups = Array(Set(players.flatMap { $0.groups })).sorted()
    }

    func reset() {
        filters = SquadFilters()
    }

    func toggle(_ position: PlayerPosition) {
        if filters.positions.contains(position) {
            filters.positions.remove(position)
        } else {
            filters.positions.insert(position)
        }
    }

    func toggle(_ availability: AvailabilityStatus) {
        if filters.availability.contains(availability) {
            filters.availability.remove(availability)
        } else {
            filters.availability.insert(availability)
        }
    }

    func toggle(_ squadStatus: SquadStatus) {
        if filters.squadStatus.contains(squadStatus) {
            filters.squadStatus.remove(squadStatus)
        } else {
            filters.squadStatus.insert(squadStatus)
        }
    }

    func toggleRole(_ role: String) {
        if filters.roles.contains(role) {
            filters.roles.remove(role)
        } else {
            filters.roles.insert(role)
        }
    }

    func toggleGroup(_ group: String) {
        if filters.groups.contains(group) {
            filters.groups.remove(group)
        } else {
            filters.groups.insert(group)
        }
    }

    func activeChips() -> [String] {
        var chips: [String] = []
        chips += filters.positions.map { $0.rawValue }
        chips += filters.availability.map { $0.rawValue }
        chips += filters.squadStatus.map { $0.rawValue }
        chips += filters.roles.map { "Rolle: \($0)" }
        chips += filters.groups.map { "Gruppe: \($0)" }
        if !filters.searchText.isEmpty {
            chips.append("Suche: \(filters.searchText)")
        }
        return chips.sorted()
    }
}
