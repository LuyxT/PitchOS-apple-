import Foundation
import CoreGraphics

enum OpponentMode: String, CaseIterable, Identifiable, Codable {
    case hidden
    case markers
    case formation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hidden:
            return "Aus"
        case .markers:
            return "Marker"
        case .formation:
            return "Formation"
        }
    }
}

enum TacticalDrawingKind: String, CaseIterable, Identifiable, Codable {
    case line
    case arrow
    case mark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .line:
            return "Linie"
        case .arrow:
            return "Pfeil"
        case .mark:
            return "Markierung"
        }
    }
}

enum TacticalZone: String, CaseIterable, Identifiable, Codable {
    case leftHalf = "Linker Halbraum"
    case rightHalf = "Rechter Halbraum"
    case center = "Zentrum"
    case leftWing = "Linker Flügel"
    case rightWing = "Rechter Flügel"
    case box = "Strafraum"

    var id: String { rawValue }
}

struct TacticalPoint: Hashable, Codable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = min(1, max(0, x))
        self.y = min(1, max(0, y))
    }

    func cgPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }

    static func from(_ point: CGPoint, in size: CGSize) -> TacticalPoint {
        guard size.width > 0, size.height > 0 else {
            return TacticalPoint(x: 0.5, y: 0.5)
        }
        return TacticalPoint(
            x: point.x / size.width,
            y: point.y / size.height
        )
    }
}

struct TacticalRole: Hashable, Codable {
    var name: String

    static let presets: [TacticalRole] = [
        TacticalRole(name: "TW"),
        TacticalRole(name: "LIV"),
        TacticalRole(name: "RIV"),
        TacticalRole(name: "LV"),
        TacticalRole(name: "RV"),
        TacticalRole(name: "6er"),
        TacticalRole(name: "8er links"),
        TacticalRole(name: "8er rechts"),
        TacticalRole(name: "10er"),
        TacticalRole(name: "LA"),
        TacticalRole(name: "RA"),
        TacticalRole(name: "ST")
    ]
}

struct TacticalPlacement: Identifiable, Hashable, Codable {
    let id: UUID
    var playerID: UUID
    var point: TacticalPoint
    var zone: TacticalZone?
    var role: TacticalRole

    init(
        id: UUID = UUID(),
        playerID: UUID,
        point: TacticalPoint,
        zone: TacticalZone? = nil,
        role: TacticalRole
    ) {
        self.id = id
        self.playerID = playerID
        self.point = point
        self.zone = zone
        self.role = role
    }
}

struct OpponentMarker: Identifiable, Hashable, Codable {
    let id: UUID
    var point: TacticalPoint
    var name: String

    init(id: UUID = UUID(), point: TacticalPoint, name: String = "") {
        self.id = id
        self.point = point
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case point
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        point = try container.decode(TacticalPoint.self, forKey: .point)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(point, forKey: .point)
        try container.encode(name, forKey: .name)
    }
}

struct TacticalNeutralMarker: Identifiable, Hashable, Codable {
    let id: UUID
    var point: TacticalPoint
    var name: String

    init(id: UUID = UUID(), point: TacticalPoint, name: String = "") {
        self.id = id
        self.point = point
        self.name = name
    }
}

struct TacticalDrawing: Identifiable, Hashable, Codable {
    let id: UUID
    var kind: TacticalDrawingKind
    var points: [TacticalPoint]
    var colorHex: String
    var isTemporary: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        kind: TacticalDrawingKind,
        points: [TacticalPoint],
        colorHex: String,
        isTemporary: Bool,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.points = points
        self.colorHex = colorHex
        self.isTemporary = isTemporary
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case points
        case colorHex
        case isTemporary
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(TacticalDrawingKind.self, forKey: .kind)
        points = try container.decode([TacticalPoint].self, forKey: .points)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        isTemporary = try container.decode(Bool.self, forKey: .isTemporary)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(points, forKey: .points)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(isTemporary, forKey: .isTemporary)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

struct TacticsScenario: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var updatedAt: Date
    var showOpponent: Bool
    var showZones: Bool
    var showLines: Bool
    var drawingsVisible: Bool

    init(
        id: UUID = UUID(),
        name: String,
        updatedAt: Date = Date(),
        showOpponent: Bool = false,
        showZones: Bool = false,
        showLines: Bool = false,
        drawingsVisible: Bool = true
    ) {
        self.id = id
        self.name = name
        self.updatedAt = updatedAt
        self.showOpponent = showOpponent
        self.showZones = showZones
        self.showLines = showLines
        self.drawingsVisible = drawingsVisible
    }
}

struct TacticsBoardState: Hashable, Codable {
    var scenarioID: UUID
    var placements: [TacticalPlacement]
    var benchPlayerIDs: [UUID]
    var excludedPlayerIDs: [UUID]
    var opponentMode: OpponentMode
    var opponentMarkers: [OpponentMarker]
    var neutralMarkers: [TacticalNeutralMarker]
    var drawings: [TacticalDrawing]

    static func empty(scenarioID: UUID, playerIDs: [UUID]) -> TacticsBoardState {
        TacticsBoardState(
            scenarioID: scenarioID,
            placements: [],
            benchPlayerIDs: playerIDs,
            excludedPlayerIDs: [],
            opponentMode: .hidden,
            opponentMarkers: OpponentMarker.defaultLine(),
            neutralMarkers: [],
            drawings: []
        )
    }
}

struct TacticsSelection: Hashable {
    var playerIDs: Set<UUID> = []
    var drawingIDs: Set<UUID> = []
}

extension OpponentMarker {
    static func defaultLine() -> [OpponentMarker] {
        [
            OpponentMarker(point: TacticalPoint(x: 0.12, y: 0.50)),
            OpponentMarker(point: TacticalPoint(x: 0.22, y: 0.20)),
            OpponentMarker(point: TacticalPoint(x: 0.22, y: 0.40)),
            OpponentMarker(point: TacticalPoint(x: 0.22, y: 0.60)),
            OpponentMarker(point: TacticalPoint(x: 0.22, y: 0.80)),
            OpponentMarker(point: TacticalPoint(x: 0.36, y: 0.20)),
            OpponentMarker(point: TacticalPoint(x: 0.36, y: 0.40)),
            OpponentMarker(point: TacticalPoint(x: 0.36, y: 0.60)),
            OpponentMarker(point: TacticalPoint(x: 0.36, y: 0.80)),
            OpponentMarker(point: TacticalPoint(x: 0.50, y: 0.35)),
            OpponentMarker(point: TacticalPoint(x: 0.50, y: 0.65))
        ]
    }

    static func legacyTopToBottomLine() -> [TacticalPoint] {
        [
            TacticalPoint(x: 0.5, y: 0.12),
            TacticalPoint(x: 0.2, y: 0.22),
            TacticalPoint(x: 0.4, y: 0.22),
            TacticalPoint(x: 0.6, y: 0.22),
            TacticalPoint(x: 0.8, y: 0.22),
            TacticalPoint(x: 0.2, y: 0.36),
            TacticalPoint(x: 0.4, y: 0.36),
            TacticalPoint(x: 0.6, y: 0.36),
            TacticalPoint(x: 0.8, y: 0.36),
            TacticalPoint(x: 0.35, y: 0.5),
            TacticalPoint(x: 0.65, y: 0.5)
        ]
    }
}
