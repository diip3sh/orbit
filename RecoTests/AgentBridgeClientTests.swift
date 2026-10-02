//
//  AgentBridgeClientTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

/// Runs the `--mcp` process for real. The test host is Reco itself, so the process is another copy of
/// it, which pipes its stdio to the host's listening socket as an agent's would.
@MainActor
struct AgentBridgeClientTests {

    private static let messages = [
        #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}"#,
        #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#,
        #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#
    ]

    /// The `--mcp` process and the pipes to its three streams.
    private struct Client {
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()

        init(environment: [String: String]) {
            process.executableURL = Bundle.main.executableURL
            process.arguments = [AgentBridgeClient.argument]
            process.environment = environment.merging(["PATH": "/usr/bin:/bin"]) { $1 }
            process.standardInput = input
            process.standardOutput = output
            process.standardError = errors
        }
    }

    /// The process's exit status, or `nil` when it's still running after `limit`, in which case it's stopped.
    private func exitStatus(of process: Process, within limit: Duration) async -> Int32? {
        let deadline = ContinuousClock.now + limit
        while process.isRunning {
            guard ContinuousClock.now < deadline else {
                process.terminate()
                return nil
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return process.terminationStatus
    }

    @Test func anAgentsProcessListsTheThreeToolsAndEndsWithItsInput() async throws {
        let client = Client(environment: [AgentServerCommand.tokenVariable: AgentBridgeServer.token()])
        let process = client.process
        let input = client.input
        let output = client.output
        try process.run()
        defer { if process.isRunning { process.terminate() } }
        for message in Self.messages {
            try input.fileHandleForWriting.write(contentsOf: Data((message + "\n").utf8))
        }

        // Stdin stays open: the process ends when it does
        let listing = Task { () -> [String] in
            for try await line in output.fileHandleForReading.bytes.lines {
                guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any], object["id"] as? Int == 2 else { continue }
                let tools = (object["result"] as? [String: Any])?["tools"] as? [[String: Any]]
                return tools?.compactMap { $0["name"] as? String } ?? []
            }
            return []
        }
        let watchdog = Task {
            try await Task.sleep(for: .seconds(20))
            process.terminate()
        }
        let names = try await listing.value
        watchdog.cancel()
        #expect(names == ["inspect_page", "record_page", "render_status", "export_recording"])

        try input.fileHandleForWriting.close()
        let status = await exitStatus(of: process, within: .seconds(5))
        #expect(status == 0)
    }

    @Test func withoutATokenItSaysWhereToConnectAndFails() async throws {
        let client = Client(environment: [:])
        try client.process.run()
        defer { try? client.input.fileHandleForWriting.close() }

        let status = await exitStatus(of: client.process, within: .seconds(10))
        let message = String(bytes: client.errors.fileHandleForReading.availableData, encoding: .utf8) ?? ""

        #expect(status == 1)
        #expect(message.contains("Settings → Agents"))
    }
}
