import Foundation

enum AppConfiguration {
    static let API_BASE_URL: String = {
        if let override = ProcessInfo.processInfo.environment["API_BASE_URL"], !override.isEmpty {
            return override
        }
        return "https://web-production-97b2a.up.railway.app"
    }()
    static let baseURL = URL(string: API_BASE_URL)!

    static var messagingEnabled: Bool {
        true
    }

    static var networkLoggingEnabled: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    static var isPlaceholder: Bool {
#if DEBUG
        false
#else
        false
#endif
    }

}
