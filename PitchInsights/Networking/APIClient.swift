import Foundation

final class APIClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let apiPrefix = "/api/v1"

    init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func send<T: Decodable>(_ endpoint: Endpoint, token: String? = nil) async throws -> T {
        let baseURL = BackendConfig.baseURL

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

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(status: httpResponse.statusCode, data: data)
        }

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

enum NetworkError: Error {
    case invalidBaseURL
    case invalidURL
    case invalidResponse
    case httpError(status: Int, data: Data)
    case emptyResponseBody
    case decodingFailed(underlying: Error)
}
