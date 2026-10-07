//
//  AgentProcessTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

/// Runs real processes (`/bin/sh`, `/bin/sleep`), never an agent.
struct AgentProcessTests {

    private let directory = FileManager.default.temporaryDirectory

    private func run(_ executable: String, _ arguments: [String], timeout: Duration = .seconds(30)) async -> AgentProcess.Result {
        await AgentProcess.run(
            executable: URL(filePath: executable), arguments: arguments, environment: ["PATH": "/usr/bin:/bin"],
            directory: directory, timeout: timeout
        )
    }

    @Test func reportsTheExitStatusAndBothOutputs() async {
        let result = await run("/bin/sh", ["-c", "echo out; echo err >&2; exit 3"])

        #expect(result.end == .exited(3))
        #expect(result.stdout == "out\n")
        #expect(result.stderr == "err\n")
    }

    @Test func givesTheProcessNoInputAndTheEnvironmentItWasGiven() async {
        let result = await run("/bin/sh", ["-c", "cat; echo $PATH"])

        #expect(result.end == .exited(0))
        #expect(result.stdout == "/usr/bin:/bin\n")
    }

    @Test func aTimeoutStopsTheProcess() async {
        let start = ContinuousClock.now

        let result = await run("/bin/sleep", ["30"], timeout: .seconds(1))

        #expect(result.end == .timedOut)
        // Well under the 30 s sleep: a busy CI runner took 6.5 s once
        #expect(start.duration(to: .now) < .seconds(15))
    }

    @Test func cancellingTheTaskStopsTheProcess() async throws {
        let start = ContinuousClock.now
        let task = Task { await run("/bin/sleep", ["30"]) }
        try await Task.sleep(for: .milliseconds(500))

        task.cancel()
        let result = await task.value

        #expect(result.end == .cancelled)
        // Well under the 30 s sleep: a busy CI runner took 6.5 s once
        #expect(start.duration(to: .now) < .seconds(15))
    }

    @Test func aMissingExecutableIsALaunchFailure() async {
        let result = await run("/no/such/agent", [])

        guard case .launchFailed(let message) = result.end else {
            Issue.record("Expected a launch failure, got \(result.end)")
            return
        }
        #expect(message.contains("agent"))
    }

    @Test func aProcessLeftRunningDoesntHoldTheResultBack() async {
        let start = ContinuousClock.now

        // The background sleep keeps the output pipe open for 10 s; the bound leaves room for a busy CI runner
        let result = await run("/bin/sh", ["-c", "sleep 10 & echo hi"])

        #expect(result.end == .exited(0))
        #expect(result.stdout == "hi\n")
        #expect(start.duration(to: .now) < .seconds(5))
    }

    @Test func onlyTheEndOfALongOutputIsKept() async {
        let result = await run("/bin/sh", ["-c", "yes abcdefghij | head -c 100000; echo END"])

        #expect(result.stdout.utf8.count <= OutputTail.defaultLimit)
        #expect(result.stdout.hasSuffix("END\n"))
    }
}
