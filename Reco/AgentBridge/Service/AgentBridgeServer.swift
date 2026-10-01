//
//  AgentBridgeServer.swift
//  Reco
//

import Foundation
import MCP
import Network
import OSLog

/// Serves Reco's tools to coding agents over MCP, on a Unix socket in Reco's Application Support folder (spec 0006).
///
/// Agents don't connect to it directly: they start Reco with `--mcp` (``AgentBridgeClient``), which
/// pipes their stdio to the socket. Each connection gets its own MCP `Server`, after the first line
/// has proved it knows the token. No HTTP server and no TCP port: only this user's processes can
/// reach it, and only with the token.
@MainActor
@Observable
final class AgentBridgeServer {

    let tools: AgentTools

    /// Whether the socket is accepting connections.
    private(set) var isListening = false

    /// Why it isn't.
    private(set) var listenError: String?

    /// How many agents are connected now.
    private(set) var sessionCount = 0

    @ObservationIgnored private let token: String
    @ObservationIgnored private var listener: NWListener?

    private static let tokenKey = "agentBridgeToken"

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "AgentBridgeServer")

    /// The socket's path. Short on purpose: a Unix socket path holds 104 bytes, and this one takes
    /// 61 plus the user name's length.
    nonisolated static var socketURL: URL {
        URL.recoSupport.appending(path: "agent.sock")
    }

    init(tools: AgentTools, token: String = AgentBridgeServer.token()) {
        self.tools = tools
        self.token = token
    }

    /// The token agents present, made on first use and kept in the app's defaults. Never logged.
    static func token(defaults: UserDefaults = .standard) -> String {
        if let token = defaults.string(forKey: tokenKey) {
            return token
        }
        let token = AgentToken.generate()
        defaults.set(token, forKey: tokenKey)
        return token
    }

    // MARK: - Listening

    /// Starts listening, taking over the socket from a stale file or another copy of the app.
    func start() {
        guard listener == nil else { return }
        let path = Self.socketURL.path(percentEncoded: false)
        try? FileManager.default.removeItem(atPath: path)
        do {
            try FileManager.default.createDirectory(at: URL.recoSupport, withIntermediateDirectories: true)
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .unix(path: path)
            let listener = try NWListener(using: parameters)
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in self?.listenerChanged(to: state) }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            listenError = error.localizedDescription
            logger.error("Couldn't listen for agents: \(error.localizedDescription)")
        }
    }

    private func listenerChanged(to state: NWListener.State) {
        switch state {
        case .ready:
            isListening = true
            listenError = nil
            logger.info("Listening for agents")
        case .failed(let error):
            isListening = false
            listenError = error.localizedDescription
            listener = nil
            logger.error("Agent socket failed: \(error.localizedDescription)")
        default:
            break
        }
    }

    // MARK: - Sessions

    private func accept(_ connection: NWConnection) {
        let transport = AgentSocketTransport(connection: connection, token: token)
        Task {
            let server = await makeServer()
            do {
                try await server.start(transport: transport)
            } catch {
                logger.warning("Rejected a connection with a wrong token")
                return
            }
            sessionCount += 1
            await server.waitUntilCompleted()
            await server.stop()
            sessionCount -= 1
        }
    }

    private func makeServer() async -> Server {
        let server = Server(
            name: AgentServerCommand.serverName,
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
            title: "Reco",
            instructions: AgentToolCatalog.instructions,
            capabilities: .init(tools: .init(listChanged: false))
        )
        let definitions = Self.mcpTools
        let tools = tools
        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: definitions)
        }
        await server.withMethodHandler(CallTool.self) { parameters in
            let arguments = try JSONEncoder().encode(parameters.arguments ?? [:])
            let reply = await tools.call(parameters.name, arguments: arguments)
            return CallTool.Result(content: [.text(text: reply.text, annotations: nil, _meta: nil)], isError: reply.isError)
        }
        return server
    }

    /// The catalog as MCP tools. A schema that doesn't parse would be a bug the catalog's tests catch.
    static var mcpTools: [Tool] {
        AgentToolCatalog.tools.map { definition in
            let schema = (try? JSONDecoder().decode(Value.self, from: Data(definition.schema.utf8))) ?? .object([:])
            return Tool(name: definition.name, description: definition.description, inputSchema: schema)
        }
    }
}
