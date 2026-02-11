import Foundation

enum AppConfiguration {
    static let API_BASE_URL = "https://web-production-97b2a.up.railway.app"
    static let baseURL = URL(string: API_BASE_URL)!

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
