//
//  RecoMain.swift
//  Reco
//

import SwiftUI

/// The app's entry point. Started with `--mcp` by a coding agent, it only bridges the agent to the
/// running app (``AgentBridgeClient``); otherwise it's the app (``RecoApp``), after bringing over
/// what the old sandboxed app kept (``ContainerMigration``).
@main
enum RecoMain {
    static func main() {
        if CommandLine.arguments.dropFirst().first == AgentBridgeClient.argument {
            AgentBridgeClient.run()
        }
        ContainerMigration.run()
        RecoApp.main()
    }
}
