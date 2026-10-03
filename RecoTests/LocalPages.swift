//
//  LocalPages.swift
//  RecoTests
//

import Foundation
import Network

/// A few HTML pages served on `http://127.0.0.1:<port>` for a test: what a `data:` page can't do,
/// like link to another page. Stops when deallocated.
final class LocalPages: @unchecked Sendable {

    private let listener: NWListener
    private let pages: [String: String]
    private let queue = DispatchQueue(label: "LocalPages")

    /// Serves `pages` by path, e.g. `["/": "<!doctype html>…", "/second": "…"]`, once the listener
    /// has its port.
    static func serving(_ pages: [String: String]) async throws -> LocalPages {
        let server = try LocalPages(pages)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            server.listener.stateUpdateHandler = { state in
                switch state {
                case .ready: continuation.resume()
                case .failed(let error): continuation.resume(throwing: error)
                default: break
                }
            }
            server.listener.start(queue: server.queue)
        }
        server.listener.stateUpdateHandler = nil
        return server
    }

    private init(_ pages: [String: String]) throws {
        self.pages = pages
        listener = try NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { [weak self] connection in self?.serve(connection) }
    }

    deinit {
        listener.cancel()
    }

    /// The address of the page at `path`.
    func url(_ path: String) -> URL {
        URL(string: "http://127.0.0.1:\(listener.port?.rawValue ?? 0)\(path)") ?? URL(filePath: "/")
    }

    private func serve(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [pages] data, _, _, _ in
            let request = String(bytes: data ?? Data(), encoding: .utf8) ?? ""
            let path = request.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
            let body = pages[path.split(separator: "?").first.map(String.init) ?? path]
            let status = body == nil ? "404 Not Found" : "200 OK"
            let content = Data((body ?? "").utf8)
            let head = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(content.count)\r\nConnection: close\r\n\r\n"
            connection.send(content: Data(head.utf8) + content, completion: .contentProcessed { _ in connection.cancel() })
        }
    }
}
