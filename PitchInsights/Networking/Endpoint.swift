import Foundation

struct Endpoint {
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    let path: String
    let method: Method
    var queryItems: [URLQueryItem] = []
    var body: Data? = nil
    var headers: [String: String] = [:]
}

extension Endpoint {
    static func get(_ path: String, query: [URLQueryItem] = []) -> Endpoint {
        Endpoint(path: path, method: .get, queryItems: query)
    }

    static func post(_ path: String, body: Data? = nil) -> Endpoint {
        Endpoint(path: path, method: .post, body: body)
    }

    static func put(_ path: String, body: Data? = nil) -> Endpoint {
        Endpoint(path: path, method: .put, body: body)
    }

    static func patch(_ path: String, body: Data? = nil) -> Endpoint {
        Endpoint(path: path, method: .patch, body: body)
    }

    static func delete(_ path: String) -> Endpoint {
        Endpoint(path: path, method: .delete)
    }
}
