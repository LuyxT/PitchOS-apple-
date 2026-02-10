import Foundation

final class MessengerRealtimeService {
    private let session: URLSession
    private var socketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var isManualDisconnect = false

    var onEvent: ((MessengerRealtimeEventDTO) -> Void)?
    var onStateChange: ((MessengerConnectionState) -> Void)?
    var onUnexpectedDisconnect: (() -> Void)?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func connect(baseURL: URL, token: String) {
        disconnect()
        isManualDisconnect = false
        onStateChange?(.connecting)

        guard let webSocketURL = Self.makeWebSocketURL(baseURL: baseURL, token: token) else {
            onStateChange?(.failed("WebSocket-URL ungültig"))
            return
        }

        let task = session.webSocketTask(with: webSocketURL)
        socketTask = task
        task.resume()
        onStateChange?(.connected)
        startReceiveLoop(task: task)
    }

    func disconnect() {
        isManualDisconnect = true
        receiveTask?.cancel()
        receiveTask = nil
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
        onStateChange?(.disconnected)
    }

    private func startReceiveLoop(task: URLSessionWebSocketTask) {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    switch message {
                    case .string(let text):
                        self.handleRawPayload(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleRawPayload(text)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    self.onStateChange?(.failed(error.localizedDescription))
                    if !self.isManualDisconnect {
                        self.onUnexpectedDisconnect?()
                    }
                    return
                }
            }
        }
    }

    private func handleRawPayload(_ payload: String) {
        guard let data = payload.data(using: .utf8) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let event = try? decoder.decode(MessengerRealtimeEventDTO.self, from: data) else { return }
        onEvent?(event)
    }

    private static func makeWebSocketURL(baseURL: URL, token: String) -> URL? {
        guard var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        if comps.scheme == "https" {
            comps.scheme = "wss"
        } else if comps.scheme == "http" {
            comps.scheme = "ws"
        }
        comps.path = "/messages/realtime"
        comps.queryItems = [URLQueryItem(name: "token", value: token)]
        return comps.url
    }
}

