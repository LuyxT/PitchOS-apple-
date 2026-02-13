import Foundation
import Combine

@MainActor
final class PlayerProfileViewModel: ObservableObject {
    @Published var draft: Player

    init(player: Player) {
        draft = player
    }

    var ageText: String {
        guard let dob = draft.dateOfBirth else { return "-" }
        let years = Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0
        return "\(years)"
    }

    var isValidQuickCreate: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && draft.number > 0
    }
}
