import Foundation

enum BackendConfig {
    static let baseURLString = "https://web-production-97b2a.up.railway.app"
    static let baseURL = URL(string: baseURLString)!
}

enum AppConfiguration {
    static var baseURLString: String { BackendConfig.baseURLString }
    static var baseURL: URL? { BackendConfig.baseURL }

    static var isPlaceholder: Bool {
        false
    }
}
