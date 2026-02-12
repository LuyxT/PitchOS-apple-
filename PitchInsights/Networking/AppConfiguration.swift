import Foundation

enum AppConfiguration {
    static let API_BASE_URL: String = {
        if let override = ProcessInfo.processInfo.environment["API_BASE_URL"], !override.isEmpty {
            return override
        }
        return "https://web-production-97b2a.up.railway.app"
    }()
    static let baseURL = URL(string: API_BASE_URL)!

    static var enabledModules: [Module] {
        let defaults: [Module] = [.kader, .mannschaftskasse]
        guard let raw = ProcessInfo.processInfo.environment["ENABLED_MODULES"], !raw.isEmpty else {
            return defaults
        }
        let parsed = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { Module(rawValue: $0) }
        return parsed.isEmpty ? defaults : parsed
    }

    static var messagingEnabled: Bool {
        false
    }

    static var networkLoggingEnabled: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    static var isPlaceholder: Bool {
        false
    }

}
