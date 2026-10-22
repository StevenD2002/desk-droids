import Foundation
import Network

/// A tiny HTTP server for Claude Code's `type: "http"` hooks.
///
/// - `POST /hook`  receives a hook payload and always answers `200` with an empty body,
///   which Claude Code treats as "no decision", so the droid can never block a tool call.
/// - `GET /state`  returns the current sessions as JSON (handy for debugging).
/// - `POST /say/<phrase>`  makes the droid say a phrase, e.g. `/say/happy` (for tuning sounds).
///
/// Listens on loopback only (IPv4 and IPv6, since `localhost` may resolve to either).
final class HookServer {
    private static let maxRequestBytes = 32 * 1024 * 1024

    private let port: UInt16
    private let onEvent: (HookEvent) -> Void
    private let snapshot: () -> Data
    private let onFailure: (String) -> Void
    private let onSay: (String) -> Bool
    private let queue = DispatchQueue(label: "desk-droids.hook-server")
    private var listeners: [NWListener] = []
    private var failedListeners = 0

    init(
        port: UInt16,
        onEvent: @escaping (HookEvent) -> Void,
        snapshot: @escaping () -> Data,
        onFailure: @escaping (String) -> Void,
        onSay: @escaping (String) -> Bool
    ) {
        self.port = port
        self.onEvent = onEvent
        self.snapshot = snapshot
        self.onFailure = onFailure
        self.onSay = onSay
    }

    func start() {
        let hosts = ["127.0.0.1", "::1"]
        for host in hosts {
            let params = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
            params.allowLocalEndpointReuse = true
            params.requiredLocalEndpoint = .hostPort(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!
            )
            do {
                let listener = try NWListener(using: params)
                listener.newConnectionHandler = { [weak self] connection in
                    self?.handle(connection)
                }
                listener.stateUpdateHandler = { [weak self] state in
                    if case .failed(let error) = state {
                        self?.listenerFailed(host: host, error: "\(error)", total: hosts.count)
                    }
                }
                listener.start(queue: queue)
                listeners.append(listener)
            } catch {
                queue.async { self.listenerFailed(host: host, error: "\(error)", total: hosts.count) }
            }
        }
    }

    // Losing one loopback family is fine; losing both means we're deaf.
    private func listenerFailed(host: String, error: String, total: Int) {
        failedListeners += 1
        NSLog("desk-droids: listener on \(host):\(port) failed: \(error)")
        if failedListeners == total {
            onFailure("Couldn't listen on port \(port). Is something else using it?")
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }

            if let request = HTTPRequest(parsing: buffer) {
                self.route(request, on: connection)
            } else if isComplete || error != nil || buffer.count > Self.maxRequestBytes {
                connection.cancel()
            } else {
                self.receive(on: connection, buffer: buffer)
            }
        }
    }

    private func route(_ request: HTTPRequest, on connection: NWConnection) {
        switch (request.method, request.path) {
        case ("POST", "/hook"):
            respond(on: connection, status: "200 OK", body: Data())
            if let event = HookEvent(json: request.body) {
                onEvent(event)
            }
        case ("GET", "/state"):
            respond(on: connection, status: "200 OK", body: snapshot(), contentType: "application/json")
        case ("POST", let path) where path.hasPrefix("/say/"):
            let known = onSay(String(path.dropFirst("/say/".count)))
            respond(on: connection, status: known ? "200 OK" : "404 Not Found", body: Data())
        default:
            respond(on: connection, status: "404 Not Found", body: Data())
        }
    }

    private func respond(on connection: NWConnection, status: String, body: Data, contentType: String = "text/plain") {
        var response = Data("""
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.count)\r
        Connection: close\r
        \r

        """.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }
}

/// Just enough HTTP/1.1 parsing for hook requests. Returns nil until the full request has arrived.
struct HTTPRequest {
    let method: String
    let path: String
    let body: Data

    init?(parsing data: Data) {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)),
              let head = String(data: data[..<headerEnd.lowerBound], encoding: .utf8)
        else { return nil }

        let lines = head.components(separatedBy: "\r\n")
        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }

        let rawBody = data[headerEnd.upperBound...]
        if headers["transfer-encoding"]?.lowercased().contains("chunked") == true {
            guard let decoded = Self.decodeChunked(rawBody) else { return nil }
            body = decoded
        } else {
            let length = Int(headers["content-length"] ?? "0") ?? 0
            guard rawBody.count >= length else { return nil }
            body = Data(rawBody.prefix(length))
        }

        method = String(requestLine[0])
        path = String(requestLine[1].split(separator: "?").first ?? "")
    }

    /// Returns nil if the terminating zero-length chunk hasn't arrived yet.
    private static func decodeChunked(_ data: Data) -> Data? {
        var output = Data()
        var index = data.startIndex
        let crlf = Data("\r\n".utf8)
        while true {
            guard let lineEnd = data.range(of: crlf, in: index..<data.endIndex),
                  let sizeLine = String(data: data[index..<lineEnd.lowerBound], encoding: .ascii),
                  let size = Int(sizeLine.split(separator: ";")[0].trimmingCharacters(in: .whitespaces), radix: 16)
            else { return nil }
            if size == 0 { return output }
            let chunkStart = lineEnd.upperBound
            guard data.distance(from: chunkStart, to: data.endIndex) >= size + 2 else { return nil }
            let chunkEnd = data.index(chunkStart, offsetBy: size)
            output.append(data[chunkStart..<chunkEnd])
            index = data.index(chunkEnd, offsetBy: 2)
        }
    }
}
