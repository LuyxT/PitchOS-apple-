import Foundation

final class APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let apiPrefix = "/api/v1"
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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = APIClient.iso8601WithFractional.date(from: value) {
                return date
            }
            if let date = APIClient.iso8601.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date format: \(value)"
            )
        }
        self.decoder = decoder
    }

    func send<T: Decodable>(_ endpoint: Endpoint, token: String? = nil) async throws -> T {
        let (data, _) = try await sendRaw(endpoint, token: token)

        if data.isEmpty {
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            throw NetworkError.emptyResponseBody
        }

        do {
            return try decoder.decode(T.self, from: data)
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
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        endpoint.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        NetworkDebugLogger.logRequest(request)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        NetworkDebugLogger.logResponse(httpResponse, data: data)
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = NetworkError.extractMessage(from: data)
            throw NetworkError.httpError(status: httpResponse.statusCode, data: data, message: message)
        }

        return (data, httpResponse)
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
}

enum NetworkError: LocalizedError {
    case invalidBaseURL
    case invalidURL
    case invalidResponse
    case httpError(status: Int, data: Data, message: String?)
    case emptyResponseBody
    case decodingFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Backend-URL ist ungültig."
        case .invalidURL:
            return "API-Anfrage konnte nicht erstellt werden."
        case .invalidResponse:
            return "Ungültige Server-Antwort."
        case .httpError(let status, _, let message):
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
            if let message = json["message"] as? String {
                return message
            }
            if let messages = json["message"] as? [String], !messages.isEmpty {
                return messages.joined(separator: " ")
            }
            if let error = json["error"] as? String {
                return error
            }
        }
        return String(data: data, encoding: .utf8)
    }

    static func userMessage(from error: Error) -> String {
        if let networkError = error as? NetworkError {
            return networkError.errorDescription ?? "Unbekannter Netzwerkfehler."
        }
        if let urlError = error as? URLError {
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
