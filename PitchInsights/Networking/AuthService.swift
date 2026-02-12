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

    @discardableResult
    func login(email: String, password: String) async throws -> AuthUserDTO? {
        let request = LoginRequest(email: email, password: password)
        let body = try JSONEncoder().encode(request)
        let payload = try await loadAuthPayload(endpoint: .post("/auth/login", body: body))
        guard !payload.accessToken.isEmpty else {
            throw AuthError.invalidAuthResponse
        }
        let refresh = payload.refreshToken.isEmpty ? payload.accessToken : payload.refreshToken
        storeTokens(AuthTokens(accessToken: payload.accessToken, refreshToken: refresh))
        if let user = payload.user {
            NotificationCenter.default.post(name: .authUserUpdated, object: user)
        }
        return payload.user
    }

    @discardableResult
    func register(email: String, password: String, passwordConfirmation: String, role: String, inviteCode: String?) async throws -> AuthUserDTO? {
        let request = RegisterRequest(
            email: email,
            password: password,
            passwordConfirmation: passwordConfirmation,
            role: role,
            inviteCode: inviteCode
        )
        let body = try JSONEncoder().encode(request)
        let payload = try await loadAuthPayload(endpoint: .post("/auth/register", body: body))
        guard !payload.accessToken.isEmpty else {
            throw AuthError.invalidAuthResponse
        }
        let refresh = payload.refreshToken.isEmpty ? payload.accessToken : payload.refreshToken
        storeTokens(AuthTokens(accessToken: payload.accessToken, refreshToken: refresh))
        if let user = payload.user {
            NotificationCenter.default.post(name: .authUserUpdated, object: user)
        }
        return payload.user
    }

    @discardableResult
    func refresh() async throws -> AuthUserDTO? {
        guard let refreshToken else { throw AuthError.missingRefreshToken }
        let request = RefreshRequest(refreshToken: refreshToken)
        let body = try JSONEncoder().encode(request)
        let payload = try await loadAuthPayload(endpoint: .post("/auth/refresh", body: body))
        guard !payload.accessToken.isEmpty else {
            throw AuthError.invalidAuthResponse
        }
        let refresh = payload.refreshToken.isEmpty ? payload.accessToken : payload.refreshToken
        storeTokens(AuthTokens(accessToken: payload.accessToken, refreshToken: refresh))
        if let user = payload.user {
            NotificationCenter.default.post(name: .authUserUpdated, object: user)
        }
        return payload.user
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

    func clearTokens() {
        keychain.delete(accessKey)
        keychain.delete(refreshKey)
    }

    private func loadAuthPayload(endpoint: Endpoint) async throws -> ParsedAuthPayload {
        let (data, _) = try await client.sendRaw(endpoint)
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw NetworkError.decodingFailed(underlying: AuthError.invalidAuthResponse)
        }

        let token = (object["accessToken"] as? String)
            ?? (object["token"] as? String)
            ?? ""
        let refresh = (object["refreshToken"] as? String)
            ?? (object["token"] as? String)
            ?? ""

        return ParsedAuthPayload(
            accessToken: token,
            refreshToken: refresh,
            user: parseUser(from: object["user"])
        )
    }

    private func parseUser(from rawUser: Any?) -> AuthUserDTO? {
        guard let user = rawUser as? [String: Any] else { return nil }
        guard
            let id = user["id"] as? String,
            let email = user["email"] as? String
        else {
            return nil
        }

        let role = user["role"] as? String
        let directClub = user["clubId"] as? String
        let org = user["organizationId"] as? String
        let createdAtString = user["createdAt"] as? String
        let createdAt = createdAtString.flatMap(Self.decodeDate)

        return AuthUserDTO(
            id: id,
            email: email,
            role: role,
            clubId: directClub ?? org,
            organizationId: org ?? directClub,
            createdAt: createdAt
        )
    }

    nonisolated private static func decodeDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let regular = ISO8601DateFormatter()
        regular.formatOptions = [.withInternetDateTime]
        return regular.date(from: value)
    }
}

private struct ParsedAuthPayload {
    let accessToken: String
    let refreshToken: String
    let user: AuthUserDTO?
}

enum AuthError: Error {
    case missingRefreshToken
    case invalidAuthResponse
}

extension Notification.Name {
    static let authUserUpdated = Notification.Name("auth.user.updated")
}
