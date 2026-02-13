import Foundation
import SwiftUI

enum Module: String, CaseIterable, Identifiable, Codable {
    case trainerProfil
    case kader
    case kalender
    case trainingsplanung
    case spielanalyse
    case taktiktafel
    case messenger
    case dateien
    case verwaltung
    case mannschaftskasse
    case einstellungen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trainerProfil: return "Mannschafts-Profile"
        case .kader: return "Kader"
        case .kalender: return "Kalender"
        case .trainingsplanung: return "Trainingsplanung"
        case .spielanalyse: return "Spielanalyse"
        case .taktiktafel: return "Taktiktafel"
        case .messenger: return "Messenger"
        case .dateien: return "Dateien"
        case .verwaltung: return "Verwaltung"
        case .mannschaftskasse: return "Mannschaftskasse"
        case .einstellungen: return "Einstellungen"
        }
    }

    var iconName: String {
        switch self {
        case .trainerProfil: return "person.crop.circle"
        case .kader: return "person.3"
        case .kalender: return "calendar"
        case .trainingsplanung: return "list.bullet.rectangle"
        case .spielanalyse: return "waveform.path.ecg"
        case .taktiktafel: return "sportscourt"
        case .messenger: return "bubble.left.and.bubble.right"
        case .dateien: return "folder"
        case .verwaltung: return "building.2"
        case .mannschaftskasse: return "banknote"
        case .einstellungen: return "gearshape"
        }
    }

    static func from(id: String) -> Module? {
        Module(rawValue: id)
    }
}

enum ModuleRegistry {
    static let allModules: [Module] = Module.allCases

    static let enabledModules: [Module] = {
        let available = Set(allModules)
        guard
            let raw = ProcessInfo.processInfo.environment["ENABLED_MODULES"],
            !raw.isEmpty
        else {
            return allModules
        }

        let requested = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { Module(rawValue: $0) }
            .filter { available.contains($0) }

        return requested.isEmpty ? allModules : requested
    }()

    static func isEnabled(_ module: Module) -> Bool {
        enabledModules.contains(module)
    }
}

enum DesktopWidgetSize: String, CaseIterable, Codable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small:
            return "Klein"
        case .medium:
            return "Mittel"
        case .large:
            return "Groß"
        }
    }

    var dimensions: CGSize {
        switch self {
        case .small:
            return CGSize(width: 220, height: 136)
        case .medium:
            return CGSize(width: 360, height: 136)
        case .large:
            return CGSize(width: 360, height: 288)
        }
    }
}

struct DesktopItem: Identifiable, Codable, Equatable {
    enum ItemType: String, Codable {
        case module
        case folder
        case widget
    }

    let id: UUID
    let type: ItemType
    let moduleId: String?
    var widgetSizeRaw: String?
    var name: String
    var position: CGPoint

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case moduleId
        case widgetSizeRaw
        case name
        case positionX
        case positionY
    }

    init(
        id: UUID,
        type: ItemType,
        moduleId: String?,
        widgetSizeRaw: String? = nil,
        name: String,
        position: CGPoint
    ) {
        self.id = id
        self.type = type
        self.moduleId = moduleId
        self.widgetSizeRaw = widgetSizeRaw
        self.name = name
        self.position = position
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(ItemType.self, forKey: .type)
        moduleId = try container.decodeIfPresent(String.self, forKey: .moduleId)
        widgetSizeRaw = try container.decodeIfPresent(String.self, forKey: .widgetSizeRaw)
        name = try container.decode(String.self, forKey: .name)
        let x = try container.decodeIfPresent(Double.self, forKey: .positionX) ?? -1
        let y = try container.decodeIfPresent(Double.self, forKey: .positionY) ?? -1
        position = CGPoint(x: x, y: y)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(moduleId, forKey: .moduleId)
        try container.encode(widgetSizeRaw, forKey: .widgetSizeRaw)
        try container.encode(name, forKey: .name)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
    }

    var module: Module? {
        guard (type == .module || type == .widget), let moduleId else { return nil }
        return Module.from(id: moduleId)
    }

    var folderName: String? {
        guard type == .folder else { return nil }
        return name
    }

    var isWidget: Bool {
        type == .widget
    }

    var widgetSize: DesktopWidgetSize {
        get {
            guard isWidget else { return .small }
            return DesktopWidgetSize(rawValue: widgetSizeRaw ?? "") ?? .medium
        }
        set {
            widgetSizeRaw = newValue.rawValue
        }
    }

    var title: String {
        if isWidget {
            return module?.title ?? name
        }
        return module?.title ?? name
    }

    var iconName: String {
        module?.iconName ?? "folder"
    }

    static func module(_ module: Module) -> DesktopItem {
        DesktopItem(id: UUID(), type: .module, moduleId: module.id, name: module.title, position: CGPoint(x: -1, y: -1))
    }

    static func folder(_ name: String) -> DesktopItem {
        DesktopItem(id: UUID(), type: .folder, moduleId: nil, name: name, position: CGPoint(x: -1, y: -1))
    }

    static func widget(_ module: Module, size: DesktopWidgetSize, position: CGPoint = CGPoint(x: -1, y: -1)) -> DesktopItem {
        DesktopItem(
            id: UUID(),
            type: .widget,
            moduleId: module.id,
            widgetSizeRaw: size.rawValue,
            name: module.title,
            position: position
        )
    }
}

enum DesktopDragPayload {
    static let widgetPrefix = "widget:"

    static func widget(module: Module, size: DesktopWidgetSize) -> String {
        "\(widgetPrefix)\(module.id):\(size.rawValue)"
    }

    static func parseWidget(_ value: String) -> (module: Module, size: DesktopWidgetSize)? {
        guard value.hasPrefix(widgetPrefix) else { return nil }
        let raw = String(value.dropFirst(widgetPrefix.count))
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let module = Module.from(id: parts[0]),
              let size = DesktopWidgetSize(rawValue: parts[1]) else { return nil }
        return (module, size)
    }
}
