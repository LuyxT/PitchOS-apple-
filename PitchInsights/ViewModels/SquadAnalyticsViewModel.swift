import Foundation
import Combine

struct SquadAnalyticsSnapshot {
    var positionCounts: [PositionGroup: Int] = [:]
    var availabilityCounts: [AvailabilityStatus: Int] = [:]
    var tacticalLineCounts: [PositionGroup: Int] = [:]
}

@MainActor
final class SquadAnalyticsViewModel: ObservableObject {
    @Published private(set) var snapshot = SquadAnalyticsSnapshot()

    func update(players: [Player]) {
        var next = SquadAnalyticsSnapshot()

        for group in PositionGroup.allCases {
            next.positionCounts[group] = players.filter { $0.primaryPosition.group == group }.count
        }

        for state in AvailabilityStatus.allCases {
            next.availabilityCounts[state] = players.filter { $0.availability == state }.count
        }

        let available = players.filter { $0.availability != .unavailable }
        for group in PositionGroup.allCases {
            next.tacticalLineCounts[group] = available.filter { $0.primaryPosition.group == group }.count
        }

        snapshot = next
    }
}
