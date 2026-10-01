//
//  AgentSocketTransport.swift
//  Reco
//

import Foundation
import Logging
import MCP
import Network

/// One agent's connection to the server, as an MCP transport: newline-delimited JSON over the
/// socket, after a first line that must be the bridge's token.
actor AgentSocketTransport: Transport {

    nonisolated let logger = Logging.Logger(label: "com.diip3sh.Reco.agent-bridge")

    private enum TransportError: Error {
        case closed
        case wrongToken
    }

    /// More than a token needs: a longer first line isn't one.
    private static let maximumTokenLine = 1024

    private let connection: NWConnection
    private let token: String
    private var buffer = LineBuffer()

    /// The lines that came with the token's.
    private var pending: [Data] = []

    init(connection: NWConnection, token: String) {
        self.connection = connection
        self.token = token
    }

    /// Starts the connection and checks the token. Throws, and closes, when it's wrong; what was
    /// received is never logged.
    func connect() async throws {
        try await start()
        var received = 0
        var lines: [Data] = []
        while lines.isEmpty {
            guard let data = try await read() else { throw TransportError.closed }
            received += data.count
            lines = buffer.append(data)
            guard !lines.isEmpty || received <= Self.maximumTokenLine else { break }
        }
        guard let first = lines.first, AgentToken.matches(String(data: first, encoding: .utf8) ?? "", token) else {
            connection.cancel()
            throw TransportError.wrongToken
        }
        pending = Array(lines.dropFirst())
    }

    func disconnect() {
        connection.cancel()
    }

    func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            connection.send(content: data + [UInt8(ascii: "\n")], completion: .contentProcessed { error in
                continuation.resume(with: error.map { .failure($0) } ?? .success(()))
            })
        }
    }

    /// The messages after the token's line, until the agent hangs up.
    func receive() -> AsyncThrowingStream<Data, any Error> {
        let (stream, continuation) = AsyncThrowingStream<Data, any Error>.makeStream()
        let task = Task { await pump(into: continuation) }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    // MARK: - Reading

    private func pump(into continuation: AsyncThrowingStream<Data, any Error>.Continuation) async {
        for line in pending {
            continuation.yield(line)
        }
        pending = []
        // A read that fails is the agent going away, however it did
        while let data = try? await read() {
            for line in buffer.append(data) {
                continuation.yield(line)
            }
        }
        continuation.finish()
    }

    private func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            nonisolated(unsafe) var finished = false
            connection.stateUpdateHandler = { state in
                guard !finished else { return }
                switch state {
                case .ready:
                    finished = true
                    continuation.resume()
                case .failed(let error):
                    finished = true
                    continuation.resume(throwing: error)
                case .cancelled:
                    finished = true
                    continuation.resume(throwing: TransportError.closed)
                default:
                    break
                }
            }
            connection.start(queue: .main)
        }
    }

    /// The next bytes, or `nil` at the end of the stream.
    private func read() async throws -> Data? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data?, any Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: data?.isEmpty == false ? data : nil)
                }
            }
        }
    }
}
