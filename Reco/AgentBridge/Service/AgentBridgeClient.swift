//
//  AgentBridgeClient.swift
//  Reco
//

import AppKit
import Foundation
import Network

/// What the app does when an agent starts it with `--mcp`: pipes the agent's stdio to the running
/// app's socket, and starts the app first if it isn't running (spec 0006). All MCP logic lives in
/// the app; stdout carries protocol bytes only.
nonisolated enum AgentBridgeClient {

    static let argument = "--mcp"

    /// How long to wait for the app to start, in seconds.
    private static let startTimeout = Duration.seconds(20)

    private static let retryInterval = Duration.milliseconds(250)

    /// Runs until stdin or the socket closes.
    static func run() -> Never {
        guard let token = ProcessInfo.processInfo.environment[AgentServerCommand.tokenVariable], !token.isEmpty else {
            quit("Connect this agent in Reco → Settings → Agents.", status: 1)
        }
        connect(token: token, deadline: .now + startTimeout, hasLaunched: false)
        dispatchMain()
    }

    private static func connect(token: String, deadline: ContinuousClock.Instant, hasLaunched: Bool) {
        let path = AgentBridgeServer.socketURL.path(percentEncoded: false)
        let connection = NWConnection(to: .unix(path: path), using: .tcp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.stateUpdateHandler = nil
                serve(connection, token: token)
            case .waiting, .failed:
                // Nobody is listening: the app isn't running
                connection.stateUpdateHandler = nil
                connection.cancel()
                if !hasLaunched {
                    launchApp()
                }
                guard ContinuousClock.now < deadline else { quit("Reco didn't start.", status: 1) }
                Task {
                    try? await Task.sleep(for: retryInterval)
                    connect(token: token, deadline: deadline, hasLaunched: true)
                }
            default:
                break
            }
        }
        connection.start(queue: .main)
    }

    /// Starts the app in the background, like opening it from the Dock without coming forward.
    private static func launchApp() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            if let error {
                note("Couldn't start Reco: \(error.localizedDescription)")
            }
        }
    }

    private static func serve(_ connection: NWConnection, token: String) {
        connection.send(content: Data((token + "\n").utf8), completion: .contentProcessed { _ in })

        FileHandle.standardInput.readabilityHandler = { input in
            let data = input.availableData
            if data.isEmpty {
                // The agent is done: finish what was sent, then go
                connection.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in exit(0) })
            } else {
                connection.send(content: data, completion: .contentProcessed { _ in })
            }
        }
        forward(from: connection)
    }

    /// Copies what the app says to stdout, until it hangs up.
    private static func forward(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, isComplete, error in
            if let data, !data.isEmpty {
                FileHandle.standardOutput.write(data)
            }
            if error != nil || isComplete {
                quit("Reco closed the connection.", status: 0)
            }
            forward(from: connection)
        }
    }

    private static func note(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    private static func quit(_ message: String, status: Int32) -> Never {
        note(message)
        exit(status)
    }
}
