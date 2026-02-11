import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case personalProfile
    case languageRegion
    case displayBehavior
    case notifications
    case securityPrivacy
    case appInfo
    case feedbackSupport
    case account

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personalProfile:
            return "Persönliches Profil"
        case .languageRegion:
            return "Sprache & Region"
        case .displayBehavior:
            return "Darstellung & Verhalten"
        case .notifications:
            return "Benachrichtigungen"
        case .securityPrivacy:
            return "Sicherheit & Datenschutz"
        case .appInfo:
            return "App-Information"
        case .feedbackSupport:
            return "Feedback & Support"
        case .account:
            return "Account"
        }
    }

    var iconName: String {
        switch self {
        case .personalProfile:
            return "person.crop.circle"
        case .languageRegion:
            return "globe"
        case .displayBehavior:
            return "paintbrush"
        case .notifications:
            return "bell"
        case .securityPrivacy:
            return "lock.shield"
        case .appInfo:
            return "info.circle"
        case .feedbackSupport:
            return "bubble.left.and.exclamationmark.bubble.right"
        case .account:
            return "person.crop.rectangle"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case de
    case en
    case fr
    case es

    var id: String { rawValue }

    var title: String {
        switch self {
        case .de: return "Deutsch"
        case .en: return "English"
        case .fr: return "Français"
        case .es: return "Español"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .de: return "de_DE"
        case .en: return "en_US"
        case .fr: return "fr_FR"
        case .es: return "es_ES"
        }
    }
}

enum AppRegionFormat: String, CaseIterable, Identifiable, Codable {
    case germany
    case us
    case uk
    case switzerland

    var id: String { rawValue }

    var title: String {
        switch self {
        case .germany: return "Deutschland"
        case .us: return "USA"
        case .uk: return "Vereinigtes Königreich"
        case .switzerland: return "Schweiz"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .germany: return "de_DE"
        case .us: return "en_US"
        case .uk: return "en_GB"
        case .switzerland: return "de_CH"
        }
    }
}

enum AppUnitSystem: String, CaseIterable, Identifiable, Codable {
    case metric
    case imperial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .metric: return "Metrisch"
        case .imperial: return "Imperial"
        }
    }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Hell"
        case .dark: return "Dunkel"
        }
    }
}

enum AppContrastMode: String, CaseIterable, Identifiable, Codable {
    case standard
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "Standard"
        case .high: return "High Contrast"
        }
    }
}

enum AppUIScale: String, CaseIterable, Identifiable, Codable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: return "Klein"
        case .medium: return "Mittel"
        case .large: return "Groß"
        }
    }

    var factor: Double {
        switch self {
        case .small: return 0.92
        case .medium: return 1
        case .large: return 1.12
        }
    }
}

struct AppPresentationSettings: Codable, Hashable {
    var language: AppLanguage
    var region: AppRegionFormat
    var timeZoneID: String
    var unitSystem: AppUnitSystem
    var appearanceMode: AppAppearanceMode
    var contrastMode: AppContrastMode
    var uiScale: AppUIScale
    var reduceAnimations: Bool
    var interactivePreviews: Bool

    static var `default`: AppPresentationSettings {
        AppPresentationSettings(
            language: .de,
            region: .germany,
            timeZoneID: TimeZone.current.identifier,
            unitSystem: .metric,
            appearanceMode: .light,
            contrastMode: .standard,
            uiScale: .medium,
            reduceAnimations: false,
            interactivePreviews: true
        )
    }
}

enum NotificationModuleKey: String, CaseIterable, Identifiable, Codable {
    case kalender
    case trainingsplanung
    case messenger
    case spielanalyse
    case verwaltung
    case mannschaftskasse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kalender: return "Kalender"
        case .trainingsplanung: return "Trainingsplanung"
        case .messenger: return "Messenger"
        case .spielanalyse: return "Spielanalyse"
        case .verwaltung: return "Verwaltung"
        case .mannschaftskasse: return "Mannschaftskasse"
        }
    }

    var subtitle: String {
        switch self {
        case .kalender: return "Neue/geänderte Termine"
        case .trainingsplanung: return "Angelegt/geändert"
        case .messenger: return "Neue Chat-Nachrichten"
        case .spielanalyse: return "Neue Clips/Marker"
        case .verwaltung: return "Rechte/Einladungen"
        case .mannschaftskasse: return "Offene Zahlungen/Transaktionen"
        }
    }
}

struct NotificationChannelState: Codable, Hashable {
    var push: Bool
    var inApp: Bool
    var email: Bool

    static var `default`: NotificationChannelState {
        NotificationChannelState(push: true, inApp: true, email: false)
    }
}

struct ModuleNotificationSetting: Identifiable, Codable, Hashable {
    let id: NotificationModuleKey
    var channels: NotificationChannelState

    init(module: NotificationModuleKey, channels: NotificationChannelState = .default) {
        id = module
        self.channels = channels
    }
}

struct NotificationSettingsState: Codable, Hashable {
    var globalEnabled: Bool
    var modules: [ModuleNotificationSetting]

    static var `default`: NotificationSettingsState {
        NotificationSettingsState(
            globalEnabled: true,
            modules: NotificationModuleKey.allCases.map { ModuleNotificationSetting(module: $0) }
        )
    }

    func channels(for module: NotificationModuleKey) -> NotificationChannelState {
        modules.first(where: { $0.id == module })?.channels ?? .default
    }
}

struct SecuritySessionInfo: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var deviceName: String
    var platformName: String
    var lastUsedAt: Date
    var ipAddress: String
    var location: String
    var isCurrentDevice: Bool

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        deviceName: String,
        platformName: String,
        lastUsedAt: Date,
        ipAddress: String,
        location: String,
        isCurrentDevice: Bool
    ) {
        self.id = id
        self.backendID = backendID
        self.deviceName = deviceName
        self.platformName = platformName
        self.lastUsedAt = lastUsedAt
        self.ipAddress = ipAddress
        self.location = location
        self.isCurrentDevice = isCurrentDevice
    }
}

struct SecurityTokenInfo: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var name: String
    var scope: String
    var lastUsedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        name: String,
        scope: String,
        lastUsedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.backendID = backendID
        self.name = name
        self.scope = scope
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
    }
}

struct SecuritySettingsState: Codable, Hashable {
    var twoFactorEnabled: Bool
    var sessions: [SecuritySessionInfo]
    var apiTokens: [SecurityTokenInfo]
    var privacyURL: String

    static var `default`: SecuritySettingsState {
        SecuritySettingsState(
            twoFactorEnabled: false,
            sessions: [
                SecuritySessionInfo(
                    backendID: "local.session.current",
                    deviceName: "MacBook Pro",
                    platformName: "macOS",
                    lastUsedAt: Date(),
                    ipAddress: "",
                    location: "Unbekannt",
                    isCurrentDevice: true
                )
            ],
            apiTokens: [],
            privacyURL: "https://pitchinsights.app/privacy"
        )
    }
}

enum AppUpdateState: String, CaseIterable, Identifiable, Codable {
    case current
    case updateAvailable
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .current: return "Aktuell"
        case .updateAvailable: return "Update verfügbar"
        case .unknown: return "Unbekannt"
        }
    }
}

struct AppInfoState: Codable, Hashable {
    var version: String
    var buildNumber: String
    var lastUpdateAt: Date
    var updateState: AppUpdateState
    var changelog: [String]

    static var `default`: AppInfoState {
        AppInfoState(
            version: "1.0.0",
            buildNumber: "1",
            lastUpdateAt: Date(),
            updateState: .current,
            changelog: [
                "Stabilitätsverbesserungen in Kader und Taktiktafel",
                "Leistungsoptimierungen im Messenger",
                "Verbesserte Backend-Synchronisation"
            ]
        )
    }
}

enum FeedbackCategory: String, CaseIterable, Identifiable, Codable {
    case feedback
    case issue
    case feature

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feedback: return "Feedback"
        case .issue: return "Problem melden"
        case .feature: return "Feature-Vorschlag"
        }
    }
}

struct FeedbackDraft: Codable, Hashable {
    var category: FeedbackCategory
    var message: String
    var screenshotPath: String?

    static var empty: FeedbackDraft {
        FeedbackDraft(category: .feedback, message: "", screenshotPath: nil)
    }
}

struct AccountContext: Identifiable, Codable, Hashable {
    let id: UUID
    var backendID: String?
    var clubName: String
    var teamName: String
    var roleTitle: String
    var isCurrent: Bool

    init(
        id: UUID = UUID(),
        backendID: String? = nil,
        clubName: String,
        teamName: String,
        roleTitle: String,
        isCurrent: Bool
    ) {
        self.id = id
        self.backendID = backendID
        self.clubName = clubName
        self.teamName = teamName
        self.roleTitle = roleTitle
        self.isCurrent = isCurrent
    }

    var displayTitle: String {
        "\(clubName) • \(teamName) • \(roleTitle)"
    }
}

struct AccountSettingsState: Codable, Hashable {
    var contexts: [AccountContext]
    var selectedContextID: UUID?
    var canDeactivateAccount: Bool
    var canLeaveTeam: Bool

    static var `default`: AccountSettingsState {
        let context = AccountContext(
            backendID: "local.context.default",
            clubName: "PitchInsights FC",
            teamName: "1. Mannschaft",
            roleTitle: "Chef-Trainer",
            isCurrent: true
        )
        return AccountSettingsState(
            contexts: [context],
            selectedContextID: context.id,
            canDeactivateAccount: false,
            canLeaveTeam: false
        )
    }
}

struct SettingsFeedbackPayload: Codable {
    let category: String
    let message: String
    let screenshotPath: String?
    let appVersion: String
    let buildNumber: String
    let deviceModel: String
    let platform: String
    let activeModuleID: String
}
