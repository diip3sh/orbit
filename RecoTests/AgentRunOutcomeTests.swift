//
//  AgentRunOutcomeTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct AgentRunOutcomeTests {

    private let before = RenderStatus(renderID: "old", status: .done, progress: 1, movie: "/old.mov")

    private func classify(_ end: AgentProcessEnd, job: RenderStatus?, output: String = "") -> AgentRunOutcome {
        AgentRunOutcome.classify(end: end, agent: .claudeCode, job: job, startingRenderID: before.renderID, outputReason: output)
    }

    private func render(_ status: RenderStatus.Status, error: String? = nil) -> RenderStatus {
        RenderStatus(renderID: "new", status: status, progress: 0.5, movie: status == .done ? "/new.mov" : nil, error: error)
    }

    @Test func cancellingWinsOverEverything() {
        #expect(classify(.cancelled, job: render(.done)) == .cancelled)
    }

    @Test func aNewFinishedRenderIsASuccessWhateverTheExitStatus() {
        #expect(classify(.exited(0), job: render(.done)) == .succeeded(movie: "/new.mov"))
        #expect(classify(.exited(1), job: render(.done), output: "boom") == .succeeded(movie: "/new.mov"))
        #expect(classify(.timedOut, job: render(.done)) == .succeeded(movie: "/new.mov"))
    }

    @Test func theRenderThatWasThereBeforeIsNotTheRuns() {
        #expect(classify(.exited(0), job: before) == .failed(reason: "The agent finished without recording."))
    }

    @Test func aTimeoutSaysSo() {
        #expect(classify(.timedOut, job: nil, output: "x") == .failed(reason: "The agent didn't finish within 15 minutes."))
    }

    @Test func anEditedMotionVideoIsASuccessOnceTheAgentFinishesWell() {
        let bundle = URL(filePath: "/v/Linear.motion")
        let edited = { (end: AgentProcessEnd) in
            AgentRunOutcome.classify(
                end: end, agent: .claudeCode, job: before, startingRenderID: before.renderID, outputReason: "", editedMotion: bundle, limit: .seconds(1200)
            )
        }
        #expect(edited(.exited(0)) == .edited(bundle: "/v/Linear.motion"))
        #expect(edited(.exited(1)) == .failed(reason: "Claude Code exited with status 1"))
        #expect(edited(.timedOut) == .failed(reason: "The agent didn't finish within 20 minutes."))
    }

    @Test func aLaunchFailureIsItsOwnMessage() {
        #expect(classify(.launchFailed("Reco couldn't start claude."), job: nil) == .failed(reason: "Reco couldn't start claude."))
    }

    @Test func aBadExitNamesTheAgentTheStatusAndWhatItPrinted() {
        #expect(classify(.exited(2), job: nil, output: "Not logged in") == .failed(reason: "Claude Code exited with status 2: Not logged in"))
        #expect(classify(.exited(2), job: nil) == .failed(reason: "Claude Code exited with status 2"))
    }

    @Test func aCleanExitAfterAFailedRenderReportsTheRendersError() {
        #expect(classify(.exited(0), job: render(.failed, error: "The page couldn't be loaded.")) == .failed(reason: "The page couldn't be loaded."))
    }

    @Test func aCleanExitWithoutARenderAddsWhatTheAgentSaid() {
        #expect(classify(.exited(0), job: nil, output: "I can't do that") == .failed(reason: "The agent finished without recording. I can't do that"))
        #expect(classify(.exited(0), job: nil) == .failed(reason: "The agent finished without recording."))
    }
}
