//
//  AgentBridgeServerTests.swift
//  RecoTests
//

import Foundation
import Network
import Testing
@testable import Reco

/// Talks to the real server: the test host is Reco itself, so its `AgentBridgeServer` is listening
/// on the socket, as it is for an agent's `--mcp` process.
@MainActor
struct AgentBridgeServerTests {

    private static let initialize = """
        {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},\
        "clientInfo":{"name":"test","version":"1"}}}
        """
    private static let initialized = #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#

    /// The reply to request `id`, as JSON.
    private func reply(to id: Int, from client: SocketClient) async throws -> [String: Any] {
        while true {
            guard case .text(let line) = await client.nextLine() else { throw SocketClient.Failure.noReply }
            let message = try #require(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            if message["id"] as? Int == id {
                return message
            }
        }
    }

    private func connectedClient() async throws -> SocketClient {
        let client = try await SocketClient.connect()
        await client.send(AgentBridgeServer.token())
        await client.send(Self.initialize)
        let message = try await reply(to: 1, from: client)
        let result = try #require(message["result"] as? [String: Any])
        #expect((result["serverInfo"] as? [String: Any])?["name"] as? String == "reco")
        #expect((result["instructions"] as? String)?.contains("inspect_page") == true)
        await client.send(Self.initialized)
        return client
    }

    private func callResult(_ name: String, arguments: String, from client: SocketClient) async throws -> (text: String, isError: Bool) {
        await client.send(#"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"\#(name)","arguments":\#(arguments)}}"#)
        let message = try await reply(to: 3, from: client)
        let result = try #require(message["result"] as? [String: Any])
        let content = try #require(result["content"] as? [[String: Any]])
        let text = try #require(content.first?["text"] as? String)
        return (text, result["isError"] as? Bool == true)
    }

    @Test func theSocketIsInRecosFolderAndFitsAUnixSocketPath() {
        let path = AgentBridgeServer.socketURL.path(percentEncoded: false)

        #expect(path.hasPrefix(URL.recoSupport.path(percentEncoded: false)))
        #expect(path.hasSuffix("/agent.sock"))
        #expect(path.utf8.count < 104)
    }

    @Test func anAgentWithTheTokenListsTheThreeTools() async throws {
        let client = try await connectedClient()
        defer { client.close() }

        await client.send(#"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#)
        let message = try await reply(to: 2, from: client)
        let result = try #require(message["result"] as? [String: Any])

        let tools = try #require(result["tools"] as? [[String: Any]])
        #expect(tools.compactMap { $0["name"] as? String } == ["inspect_page", "record_page", "render_status"])
        #expect(tools.allSatisfy { ($0["inputSchema"] as? [String: Any])?["type"] as? String == "object" })
    }

    @Test func aWrongTokenGetsTheConnectionClosed() async throws {
        let client = try await SocketClient.connect()
        defer { client.close() }

        await client.send("not-the-token")
        await client.send(Self.initialize)

        #expect(await client.nextLine() == .closed)
    }

    @Test func aCallThatGoesWrongIsAnErrorTextNotAProtocolFailure() async throws {
        let client = try await connectedClient()
        defer { client.close() }

        let badURL = try await callResult("record_page", arguments: #"{"url":"not a page","steps":[]}"#, from: client)
        let missingSteps = try await callResult("record_page", arguments: #"{"url":"example.com"}"#, from: client)
        let unknownRender = try await callResult("render_status", arguments: #"{"render_id":"nope"}"#, from: client)
        let unknownTool = try await callResult("delete_everything", arguments: "{}", from: client)

        #expect(badURL.isError && badURL.text.contains("url"))
        #expect(missingSteps.isError && missingSteps.text.contains("steps"))
        #expect(unknownRender.isError && unknownRender.text.contains("render_id"))
        #expect(unknownTool.isError && unknownTool.text.contains("delete_everything"))
    }
}

/// A client of the agent socket that reads whole lines, as the `--mcp` process does.
private actor SocketClient {

    enum Failure: Error {
        case noReply
        case notListening
    }

    enum Line: Equatable {
        case text(String)
        case closed
        case timedOut
    }

    private let connection: NWConnection
    private let lines: Lines

    /// The lines read so far, one at a time. Not an actor's own state: an iterator can't be advanced there.
    private final class Lines: @unchecked Sendable {
        private var iterator: AsyncStream<Data>.Iterator

        init(_ stream: AsyncStream<Data>) {
            iterator = stream.makeAsyncIterator()
        }

        func next() async -> Data? {
            await iterator.next()
        }
    }

    /// Reads the connection into `continuation`, a line at a time.
    private final class Reader: @unchecked Sendable {
        private var buffer = LineBuffer()

        func read(_ connection: NWConnection, into continuation: AsyncStream<Data>.Continuation) {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, isComplete, error in
                for line in self.buffer.append(data ?? Data()) {
                    continuation.yield(line)
                }
                if error != nil || isComplete {
                    continuation.finish()
                } else {
                    self.read(connection, into: continuation)
                }
            }
        }
    }

    private init(connection: NWConnection) {
        self.connection = connection
        let (stream, continuation) = AsyncStream<Data>.makeStream()
        lines = Lines(stream)
        Reader().read(connection, into: continuation)
    }

    /// Connects, waiting for the app to start listening.
    static func connect() async throws -> SocketClient {
        let path = AgentBridgeServer.socketURL.path(percentEncoded: false)
        for _ in 0..<40 {
            let connection = NWConnection(to: .unix(path: path), using: .tcp)
            if await ready(connection) {
                return SocketClient(connection: connection)
            }
            connection.cancel()
            try await Task.sleep(for: .milliseconds(250))
        }
        throw Failure.notListening
    }

    private static func ready(_ connection: NWConnection) async -> Bool {
        await withCheckedContinuation { continuation in
            nonisolated(unsafe) var finished = false
            connection.stateUpdateHandler = { state in
                guard !finished else { return }
                switch state {
                case .ready:
                    finished = true
                    continuation.resume(returning: true)
                case .waiting, .failed, .cancelled:
                    finished = true
                    continuation.resume(returning: false)
                default:
                    break
                }
            }
            connection.start(queue: .main)
        }
    }

    func send(_ line: String) async {
        await withCheckedContinuation { continuation in
            connection.send(content: Data((line + "\n").utf8), completion: .contentProcessed { _ in continuation.resume() })
        }
    }

    /// The next line the server sends, or `.closed` when it hangs up, or `.timedOut` after 10 s.
    func nextLine() async -> Line {
        await withTaskGroup(of: Line.self) { group in
            group.addTask { await self.readLine() }
            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return .timedOut
            }
            defer { group.cancelAll() }
            return await group.next() ?? .timedOut
        }
    }

    private func readLine() async -> Line {
        await lines.next().flatMap { String(data: $0, encoding: .utf8) }.map { .text($0) } ?? .closed
    }

    nonisolated func close() {
        connection.cancel()
    }
}
