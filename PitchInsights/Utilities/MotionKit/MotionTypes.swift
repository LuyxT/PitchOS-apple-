import SwiftUI

enum MotionEvent: String, CaseIterable {
    case create
    case update
    case delete
    case success
    case error
    case progress
    case navigation
    case sync
    case offline
    case online
}

enum MotionSeverity: String, Codable, CaseIterable {
    case info
    case success
    case warning
    case error

    var tint: Color {
        switch self {
        case .info:
            return AppTheme.primary
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

enum MotionSound: String, Codable, CaseIterable, Identifiable {
    case tick
    case success
    case warning
    case error
    case pop

    var id: String { rawValue }
}

enum MotionAnimationIntensity: String, Codable, CaseIterable, Identifiable {
    case subtle
    case normal
    case strong

    var id: String { rawValue }

    var springResponse: Double {
        switch self {
        case .subtle:
            return 0.26
        case .normal:
            return 0.22
        case .strong:
            return 0.18
        }
    }

    var damping: Double {
        switch self {
        case .subtle:
            return 0.92
        case .normal:
            return 0.86
        case .strong:
            return 0.8
        }
    }
}

enum MotionScope: String, Codable, CaseIterable, Identifiable {
    case global
    case dashboard
    case profile
    case kader
    case kalender
    case trainingsplan
    case analyse
    case messenger
    case verwaltung
    case mannschaftskasse
    case dateien
    case taktik

    var id: String { rawValue }
}

struct MotionContext: Hashable {
    let scope: MotionScope
    let contextId: String?

    init(scope: MotionScope, contextId: String? = nil) {
        self.scope = scope
        self.contextId = contextId
    }
}

struct MotionPayload {
    var title: String
    var subtitle: String?
    var iconName: String
    var severity: MotionSeverity
    var contextId: String?
    var undoAction: (() -> Void)?
    var progress: Double?
    var sound: MotionSound?
    var haptic: HapticStyle?
    var scope: MotionScope
    var ctaTitle: String?
    var ctaAction: (() -> Void)?

    init(
        title: String,
        subtitle: String? = nil,
        iconName: String = "checkmark.circle.fill",
        severity: MotionSeverity = .info,
        contextId: String? = nil,
        undoAction: (() -> Void)? = nil,
        progress: Double? = nil,
        sound: MotionSound? = nil,
        haptic: HapticStyle? = nil,
        scope: MotionScope = .global,
        ctaTitle: String? = nil,
        ctaAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.severity = severity
        self.contextId = contextId
        self.undoAction = undoAction
        self.progress = progress
        self.sound = sound
        self.haptic = haptic
        self.scope = scope
        self.ctaTitle = ctaTitle
        self.ctaAction = ctaAction
    }
}

struct MotionSettings: Codable, Equatable {
    var reduceMotionRespect: Bool
    var soundsEnabled: Bool
    var hapticsEnabled: Bool
    var intensity: MotionAnimationIntensity

    static let storageKey = "pitchinsights.motion.settings"

    static var `default`: MotionSettings {
        MotionSettings(
            reduceMotionRespect: true,
            soundsEnabled: true,
            hapticsEnabled: true,
            intensity: .normal
        )
    }

    static func load() -> MotionSettings {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(MotionSettings.self, from: data)
        else {
            return .default
        }
        return decoded
    }

    func persist() {
        guard let encoded = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.storageKey)
    }
}
