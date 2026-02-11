import Foundation

final class AuthService {
    private let client: APIClient
    private let keychain = KeychainStore.shared

    private let accessKey = "pitchinsights.accessToken"
    private let refreshKey = "pitchinsights.refreshToken"

    init(client: APIClient) {
        self.client = client
    }

    var accessToken: String? {
        keychain.get(accessKey)
    }

    var refreshToken: String? {
        keychain.get(refreshKey)
    }

    func login(email: String, password: String) async throws {
        let request = LoginRequest(email: email, password: password)
        let body = try JSONEncoder().encode(request)
        let response: LoginResponse = try await client.send(.post("/auth/login", body: body))
        storeTokens(AuthTokens(accessToken: response.accessToken, refreshToken: response.refreshToken))
        if let user = response.user {
            NotificationCenter.default.post(name: .authUserUpdated, object: user)
        }
    }

    func register(email: String, password: String) async throws {
        let request = RegisterRequest(email: email, password: password)
        let body = try JSONEncoder().encode(request)
        let response: RegisterResponse = try await client.send(.post("/auth/register", body: body))
        storeTokens(AuthTokens(accessToken: response.accessToken, refreshToken: response.refreshToken))
        if let user = response.user {
            NotificationCenter.default.post(name: .authUserUpdated, object: user)
        }
    }

    func refresh() async throws {
        guard let refreshToken else { throw AuthError.missingRefreshToken }
        let request = RefreshRequest(refreshToken: refreshToken)
        let body = try JSONEncoder().encode(request)
        let response: RefreshResponse = try await client.send(.post("/auth/refresh", body: body))
        storeTokens(AuthTokens(accessToken: response.accessToken, refreshToken: response.refreshToken))
        if let user = response.user {
            NotificationCenter.default.post(name: .authUserUpdated, object: user)
        }
    }

    func logout(using backend: BackendRepository? = nil) async {
        if let backend, let refreshToken = refreshToken {
            _ = try? await backend.logout(refreshToken: refreshToken)
        }
        keychain.delete(accessKey)
        keychain.delete(refreshKey)
    }

    private func storeTokens(_ tokens: AuthTokens) {
        keychain.set(tokens.accessToken, forKey: accessKey)
        keychain.set(tokens.refreshToken, forKey: refreshKey)
    }
}

enum AuthError: Error {
    case missingRefreshToken
}

extension Notification.Name {
    static let authUserUpdated = Notification.Name("auth.user.updated")
}
