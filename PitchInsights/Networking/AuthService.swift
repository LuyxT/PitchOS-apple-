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
        let normalizedRole = mapRoleForBackend(role)
        let request = RegisterRequest(
            email: email,
            password: password,
            passwordConfirmation: passwordConfirmation,
            role: normalizedRole,
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
        clearTokens(notify: true)
    }

    private func storeTokens(_ tokens: AuthTokens) {
        keychain.set(tokens.accessToken, forKey: accessKey)
        keychain.set(tokens.refreshToken, forKey: refreshKey)
    }

    func clearTokens(notify: Bool = false) {
        keychain.delete(accessKey)
        keychain.delete(refreshKey)
        if notify {
            NotificationCenter.default.post(name: .authSessionInvalidated, object: nil)
        }
    }

    private func loadAuthPayload(endpoint: Endpoint) async throws -> ParsedAuthPayload {
        let (data, _) = try await client.sendRaw(endpoint)
        let responseText = String(data: data, encoding: .utf8) ?? ""
        if !responseText.isEmpty {
            print("[Auth] payload: \(responseText)")
        }

        let rootObject = try parseJSONDictionary(from: data, fallbackText: responseText)
        let object = resolveAuthObject(from: rootObject)

        let token = (object["accessToken"] as? String)
            ?? (object["access_token"] as? String)
            ?? (object["token"] as? String)
            ?? (object["jwt"] as? String)
            ?? ""
        let refresh = (object["refreshToken"] as? String)
            ?? (object["refresh_token"] as? String)
            ?? (object["token"] as? String)
            ?? ""

        if token.isEmpty {
            if let message = extractServerMessage(from: object) ?? extractServerMessage(from: rootObject),
               !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw AuthError.serverMessage(message)
            }
            throw AuthError.invalidAuthResponse
        }

        let userObject = object["user"] ?? object["account"] ?? rootObject["user"] ?? rootObject["account"]

        return ParsedAuthPayload(
            accessToken: token,
            refreshToken: refresh,
            user: parseUser(from: userObject)
        )
    }

    private func parseJSONDictionary(from data: Data, fallbackText: String) throws -> [String: Any] {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return object
        }

        if let extracted = extractJSONObject(from: fallbackText),
           let extractedData = extracted.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: extractedData) as? [String: Any] {
            return object
        }

        throw AuthError.invalidAuthResponse
    }

    private func resolveAuthObject(from rootObject: [String: Any]) -> [String: Any] {
        if hasAuthTokenFields(rootObject) {
            return rootObject
        }

        var queue: [Any] = [rootObject]
        var iterations = 0

        while !queue.isEmpty && iterations < 24 {
            iterations += 1
            let current = queue.removeFirst()
            guard let dict = asDictionary(current) else { continue }

            if hasAuthTokenFields(dict) {
                return dict
            }

            for key in ["data", "result", "payload", "response", "auth"] {
                if let nested = dict[key] {
                    queue.append(nested)
                }
            }
        }

        return rootObject
    }

    private func hasAuthTokenFields(_ object: [String: Any]) -> Bool {
        object["accessToken"] is String
            || object["access_token"] is String
            || object["token"] is String
            || object["jwt"] is String
    }

    private func asDictionary(_ value: Any) -> [String: Any]? {
        if let dict = value as? [String: Any] {
            return dict
        }
        if let text = value as? String,
           let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        return nil
    }

    private func extractServerMessage(from object: [String: Any]) -> String? {
        if let message = object["message"] as? String, !message.isEmpty {
            return message
        }
        if let messages = object["message"] as? [String], let first = messages.first, !first.isEmpty {
            return first
        }
        if let error = object["error"] as? String, !error.isEmpty {
            return error
        }
        if let error = object["error"] as? [String: Any] {
            if let message = error["message"] as? String, !message.isEmpty {
                return message
            }
            if let code = error["code"] as? String, !code.isEmpty {
                return code
            }
        }
        return nil
    }

    private func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            return nil
        }
        guard start <= end else { return nil }
        return String(text[start...end])
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
        let team = user["teamId"] as? String
        let org = user["organizationId"] as? String
        let createdAtString = user["createdAt"] as? String
        let createdAt = createdAtString.flatMap(Self.decodeDate)

        return AuthUserDTO(
            id: id,
            email: email,
            role: role,
            clubId: directClub ?? org,
            teamId: team,
            organizationId: org ?? directClub,
            createdAt: createdAt
        )
    }

    private func mapRoleForBackend(_ rawRole: String) -> String {
        switch rawRole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "trainer":
            return "TRAINER"
        case "vorstand", "board":
            return "BOARD"
        case "staff", "physio", "spieler", "player":
            return "STAFF"
        default:
            return "TRAINER"
        }
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
    case serverMessage(String)
}

extension AuthError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingRefreshToken:
            return "Refresh-Token fehlt."
        case .invalidAuthResponse:
            return "Server-Antwort konnte nicht verarbeitet werden."
        case .serverMessage(let message):
            return message
        }
    }
}

extension Notification.Name {
    static let authUserUpdated = Notification.Name("auth.user.updated")
    static let authSessionInvalidated = Notification.Name("auth.session.invalidated")
}
