import Foundation

enum AppConfiguration {
    // Default placeholder URL. Override via:
    // 1) Env var `PITCHINSIGHTS_API_BASE_URL` (Xcode Scheme)
    // 2) UserDefaults key `pitchinsights.apiBaseURL`
    private static let defaultBaseURLString = "https://api.your-backend.example"
    private static let userDefaultsBaseURLKey = "pitchinsights.apiBaseURL"
    private static let envBaseURLKey = "PITCHINSIGHTS_API_BASE_URL"
    private static let envPlaceholderKey = "PITCHINSIGHTS_PLACEHOLDER_MODE"
    private static let userDefaultsPlaceholderKey = "pitchinsights.forcePlaceholder"

    static var baseURLString: String {
        if let stored = UserDefaults.standard.string(forKey: userDefaultsBaseURLKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !stored.isEmpty {
            return stored
        }

        if let env = ProcessInfo.processInfo.environment[envBaseURLKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty {
            return env
        }

        return defaultBaseURLString
    }

    static var baseURL: URL? {
        URL(string: baseURLString)
    }

    static var forcePlaceholderMode: Bool {
        if UserDefaults.standard.bool(forKey: userDefaultsPlaceholderKey) {
            return true
        }

        guard let env = ProcessInfo.processInfo.environment[envPlaceholderKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return false
        }
        return env == "1" || env == "true" || env == "yes"
    }

    static var isPlaceholder: Bool {
        forcePlaceholderMode ||
            baseURL == nil ||
            baseURLString.contains("your-backend.example")
    }
}
