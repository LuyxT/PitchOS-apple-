import Foundation

final class APIClient {
    private let session: URLSession
    private let apiPrefix = "/api/v1"
    private let requestTimeout: TimeInterval = 10
    private let accessTokenKey = "pitchinsights.accessToken"
    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send<T: Decodable>(_ endpoint: Endpoint, token: String? = nil) async throws -> T {
        let (data, _) = try await sendRaw(endpoint, token: token)

        if data.isEmpty {
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            throw NetworkError.emptyResponseBody
        }

        if let value: T = try? await decodeEnvelopePayload(T.self, from: data) {
            return value
        }

        do {
            return try await decode(T.self, from: data)
        } catch {
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            throw NetworkError.decodingFailed(underlying: error)
        }
    }

    func sendRaw(_ endpoint: Endpoint, token: String? = nil) async throws -> (Data, HTTPURLResponse) {
        let baseURL = AppConfiguration.baseURL

        let resolvedPath = normalizedPath(endpoint.path, baseURL: baseURL)
        var components = URLComponents(url: baseURL.appendingPathComponent(resolvedPath), resolvingAgainstBaseURL: false)
        if !endpoint.queryItems.isEmpty {
            components?.queryItems = endpoint.queryItems
        }
        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        endpoint.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        let effectiveToken = token ?? KeychainStore.shared.get(accessTokenKey)
        if let effectiveToken, !effectiveToken.isEmpty {
            request.setValue("Bearer \(effectiveToken)", forHTTPHeaderField: "Authorization")
        }

        NetworkDebugLogger.logRequest(request)

        let (data, response) = try await withTimeout(seconds: requestTimeout) { [session] in
            try await session.data(for: request)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        NetworkDebugLogger.logResponse(httpResponse, data: data)
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = NetworkError.extractMessage(from: data)
            if httpResponse.statusCode == 401 {
                throw NetworkError.unauthorized(data: data, message: message)
            }
            if httpResponse.statusCode == 404 {
                print("[Network][warn] 404: \(request.httpMethod ?? "GET") \(url.absoluteString)")
            }
            throw NetworkError.httpError(status: httpResponse.statusCode, data: data, message: message)
        }

        return (data, httpResponse)
    }

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw URLError(.timedOut)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func normalizedPath(_ rawPath: String, baseURL: URL) -> String {
        let path = rawPath.hasPrefix("/") ? rawPath : "/\(rawPath)"
        if path == "/health" || path == "/bootstrap" || path.hasPrefix("/api/") {
            return path
        }
        if baseURL.path == apiPrefix || baseURL.path.hasSuffix("\(apiPrefix)/") {
            return path
        }
        return "\(apiPrefix)\(path)"
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) async throws -> T {
        try APIClient.makeDecoder().decode(type, from: data)
    }

    private func decodeEnvelopePayload<T: Decodable>(_ type: T.Type, from data: Data) async throws -> T {
        let envelope = try await decode(APIEnvelope<T>.self, from: data)
        if envelope.success {
            if let payload = envelope.data {
                return payload
            }
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            throw NetworkError.emptyResponseBody
        }

        let message = envelope.error?.message ?? "Unbekannter Serverfehler."
        throw NetworkError.httpError(status: 400, data: data, message: message)
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = iso8601WithFractional.date(from: value) {
                return date
            }
            if let date = iso8601.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(value)"
            )
        }
        return decoder
    }
}

enum NetworkError: LocalizedError {
    case invalidBaseURL
    case invalidURL
    case invalidResponse
    case unauthorized(data: Data, message: String?)
    case httpError(status: Int, data: Data, message: String?)
    case emptyResponseBody
    case decodingFailed(underlying: Error)

    var isUnauthorized: Bool {
        if case .unauthorized = self { return true }
        return false
    }

    /// Returns true when the given error indicates a connectivity problem
    /// (device offline, DNS failure, timeout, etc.) rather than an HTTP-level error.
    static func isConnectivity(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost,
                 .cannotConnectToHost, .cannotFindHost, .timedOut,
                 .dnsLookupFailed, .secureConnectionFailed:
                return true
            default:
                return false
            }
        }
        if let bootstrap = error as? BootstrapCheckError, bootstrap == .timeout {
            return true
        }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Backend-URL ist ungültig."
        case .invalidURL:
            return "API-Anfrage konnte nicht erstellt werden."
        case .invalidResponse:
            return "Ungültige Server-Antwort."
        case .unauthorized(_, let message):
            if let message, !message.isEmpty {
                return "Nicht autorisiert: \(message)"
            }
            return "Nicht autorisiert. Bitte erneut anmelden."
        case .httpError(let status, _, let message):
            if status >= 500 {
                return "Der Server ist aktuell nicht erreichbar. Bitte versuche es später erneut."
            }
            if let message, !message.isEmpty {
                return "Serverfehler (\(status)): \(message)"
            }
            return "Serverfehler (\(status))."
        case .emptyResponseBody:
            return "Server hat keine Daten zurückgegeben."
        case .decodingFailed:
            return "Server-Antwort konnte nicht verarbeitet werden."
        }
    }

    static func extractMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let success = json["success"] as? Bool,
               success == false,
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String,
               !message.isEmpty {
                return message
            }
            if let message = json["message"] as? String {
                return message
            }
            if let messages = json["message"] as? [String], !messages.isEmpty {
                return messages.joined(separator: " ")
            }
            if let error = json["error"] as? String {
                return error
            }
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String,
               !message.isEmpty {
                return message
            }
        }
        return String(data: data, encoding: .utf8)
    }

    static func userMessage(from error: Error) -> String {
        if let networkError = error as? NetworkError {
            return networkError.errorDescription ?? "Unbekannter Netzwerkfehler."
        }
        if let urlError = error as? URLError {
            if isConnectivity(urlError) {
                return "Keine Verbindung zum Server. Bitte prüfe deine Internetverbindung."
            }
            return urlError.localizedDescription
        }
        return error.localizedDescription
    }
}

enum NetworkDebugLogger {
    static func logRequest(_ request: URLRequest) {
        guard AppConfiguration.networkLoggingEnabled else { return }
        let method = request.httpMethod ?? ""
        let url = request.url?.absoluteString ?? ""
        let headers = request.allHTTPHeaderFields ?? [:]
        let body = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "<empty>"
        print("[Network] -> \(method) \(url)")
        print("[Network] Headers: \(headers)")
        print("[Network] Body: \(body)")
    }

    static func logResponse(_ response: HTTPURLResponse, data: Data) {
        guard AppConfiguration.networkLoggingEnabled else { return }
        let url = response.url?.absoluteString ?? ""
        let status = response.statusCode
        let body = String(data: data, encoding: .utf8) ?? "<binary>"
        print("[Network] <- \(status) \(url)")
        print("[Network] Response: \(body)")
    }
}

private struct APIEnvelope<Payload: Decodable>: Decodable {
    let success: Bool
    let data: Payload?
    let error: APIEnvelopeError?
}

private struct APIEnvelopeError: Decodable {
    let code: String?
    let message: String?
}
