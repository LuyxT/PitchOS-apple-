import Foundation

enum PositionGroup: String, CaseIterable, Identifiable, Codable {
    case goalkeeper = "Tor"
    case defense = "Verteidigung"
    case midfield = "Mittelfeld"
    case attack = "Angriff"

    var id: String { rawValue }
}

enum PlayerPosition: String, CaseIterable, Identifiable, Codable {
    case tw = "TW"
    case iv = "IV"
    case lv = "LV"
    case rv = "RV"
    case dm = "DM"
    case zm = "ZM"
    case om = "OM"
    case la = "LA"
    case ra = "RA"
    case st = "ST"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tw: return "Torwart"
        case .iv: return "Innenverteidiger"
        case .lv: return "Linksverteidiger"
        case .rv: return "Rechtsverteidiger"
        case .dm: return "Defensives Mittelfeld"
        case .zm: return "Zentrales Mittelfeld"
        case .om: return "Offensives Mittelfeld"
        case .la: return "Linksaußen"
        case .ra: return "Rechtsaußen"
        case .st: return "Stürmer"
        }
    }

    var group: PositionGroup {
        switch self {
        case .tw:
            return .goalkeeper
        case .iv, .lv, .rv:
            return .defense
        case .dm, .zm, .om:
            return .midfield
        case .la, .ra, .st:
            return .attack
        }
    }

    static func from(code: String) -> PlayerPosition {
        PlayerPosition(rawValue: code.uppercased()) ?? .zm
    }
}

enum PreferredFoot: String, CaseIterable, Identifiable, Codable {
    case left = "Links"
    case right = "Rechts"
    case both = "Beidfüßig"

    var id: String { rawValue }
}

enum SquadStatus: String, CaseIterable, Identifiable, Codable {
    case active = "Aktiv"
    case prospect = "Perspektive"
    case rehab = "Reha"

    var id: String { rawValue }
}

enum AvailabilityStatus: String, CaseIterable, Identifiable, Codable {
    case fit = "Fit"
    case limited = "Angeschlagen"
    case unavailable = "Nicht verfügbar"

    var id: String { rawValue }

    static func fromBackend(_ value: String) -> AvailabilityStatus {
        switch value.lowercased() {
        case "fit":
            return .fit
        case "fraglich", "angeschlagen", "questionable":
            return .limited
        case "verletzt", "injured", "nicht verfuegbar", "nicht verfügbar", "unavailable":
            return .unavailable
        default:
            return .fit
        }
    }
}

enum SquadSortField: String, CaseIterable, Identifiable {
    case number = "Nummer"
    case name = "Name"
    case primaryPosition = "Position"
    case availability = "Verfügbarkeit"
    case squadStatus = "Teamstatus"

    var id: String { rawValue }
}

struct SquadFilters: Equatable {
    var searchText: String = ""
    var positions: Set<PlayerPosition> = []
    var availability: Set<AvailabilityStatus> = []
    var squadStatus: Set<SquadStatus> = []
    var roles: Set<String> = []
    var groups: Set<String> = []
}

struct Player: Identifiable, Equatable {
    let id: UUID
    var name: String
    var number: Int
    var dateOfBirth: Date?
    var primaryPosition: PlayerPosition
    var secondaryPositions: [PlayerPosition]
    var heightCm: Int?
    var weightKg: Int?
    var preferredFoot: PreferredFoot?
    var teamName: String
    var squadStatus: SquadStatus
    var availability: AvailabilityStatus
    var joinedAt: Date?
    var roles: [String]
    var groups: [String]
    var injuryStatus: String
    var notes: String
    var developmentGoals: String

    // Compatibility fields used by existing module views.
    var position: String { primaryPosition.rawValue }
    var status: AvailabilityStatus { availability }

    init(
        id: UUID,
        name: String,
        number: Int,
        position: String,
        status: AvailabilityStatus,
        dateOfBirth: Date? = nil,
        secondaryPositions: [PlayerPosition] = [],
        heightCm: Int? = nil,
        weightKg: Int? = nil,
        preferredFoot: PreferredFoot? = nil,
        teamName: String = "1. Mannschaft",
        squadStatus: SquadStatus = .active,
        joinedAt: Date? = nil,
        roles: [String] = [],
        groups: [String] = [],
        injuryStatus: String = "",
        notes: String = "",
        developmentGoals: String = ""
    ) {
        self.id = id
        self.name = name
        self.number = number
        self.dateOfBirth = dateOfBirth
        self.primaryPosition = PlayerPosition.from(code: position)
        self.secondaryPositions = secondaryPositions
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.preferredFoot = preferredFoot
        self.teamName = teamName
        self.squadStatus = squadStatus
        self.availability = status
        self.joinedAt = joinedAt
        self.roles = roles
        self.groups = groups
        self.injuryStatus = injuryStatus
        self.notes = notes
        self.developmentGoals = developmentGoals
    }
}
