//
//  WebRecordingViewModelTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

@MainActor
struct WebRecordingViewModelTests {

    /// A script file of the test's own, so nothing touches the app's.
    private let storeURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString)/WebScript.json")

    private func makeViewModel() -> WebRecordingViewModel {
        WebRecordingViewModel(settings: SettingsStore(), storeURL: storeURL) { _ in }
    }

    /// Makes an edit in its own undo group, as each event is in the app.
    private func step(_ viewModel: WebRecordingViewModel, _ change: () -> Void) {
        viewModel.undoManager.groupsByEvent = false
        viewModel.undoManager.beginUndoGrouping()
        change()
        viewModel.undoManager.endUndoGrouping()
    }

    @Test func readsAddressesAsWebPages() {
        #expect(WebScript.url(from: " example.com/pricing ")?.absoluteString == "https://example.com/pricing")
        #expect(WebScript.url(from: "localhost:3000")?.absoluteString == "http://localhost:3000")
        #expect(WebScript.url(from: "http://example.com")?.absoluteString == "http://example.com")
        #expect(WebScript.url(from: "example.com/in?next=https://example.com")?.absoluteString == "https://example.com/in?next=https://example.com")
        #expect(WebScript.url(from: "localhost.run/demo")?.absoluteString == "https://localhost.run/demo")
        #expect(WebScript.url(from: "127.0.0.1")?.absoluteString == "http://127.0.0.1")
        #expect(WebScript.url(from: "") == nil)
        #expect(WebScript.url(from: "not a page") == nil)
        #expect(WebScript.url(from: "ftp://example.com") == nil)
    }

    @Test func aNewCursorClipIsSelectedAndWaitsForItsTarget() throws {
        let viewModel = makeViewModel()

        viewModel.addPointerClip(.click)

        let clip = try #require(viewModel.script.pointer.first)
        #expect(clip.range == 0..<PointerClip.defaultDuration)
        #expect(clip.action == .click)
        #expect(viewModel.selection == clip.id)
        #expect(viewModel.isPicking)
        #expect(!viewModel.canAddPointerClip)

        let target = WebTarget(selector: "#buy", anchor: CGPoint(x: 0.2, y: 0.5), point: CGPoint(x: 40, y: 50))
        viewModel.preview.onPick?(target)

        #expect(viewModel.script.pointer.first?.target == target)
        #expect(!viewModel.isPicking)
    }

    @Test func selectingAnotherClipStopsPicking() async {
        let viewModel = makeViewModel()
        viewModel.addPointerClip(.hover)
        viewModel.seek(to: 5)
        await viewModel.addScrollClip()

        #expect(!viewModel.isPicking)
        #expect(viewModel.selectedScrollClip?.range == 5..<5 + ScrollClip.defaultDuration)
    }

    @Test func editsAreUndoneOneByOne() {
        let viewModel = makeViewModel()
        step(viewModel) { viewModel.addPointerClip(.hover) }
        let id = viewModel.script.pointer[0].id
        step(viewModel) { viewModel.moveClip(id, by: 2) }

        #expect(viewModel.script.pointer[0].range == 2..<3)
        viewModel.undoManager.undo()
        #expect(viewModel.script.pointer[0].range == 0..<1)
        viewModel.undoManager.undo()
        #expect(viewModel.script.pointer.isEmpty)
        #expect(viewModel.selection == nil)
    }

    @Test func undoingTheFirstPageLeavesNone() {
        let viewModel = makeViewModel()
        step(viewModel) {
            viewModel.address = "example.com"
            viewModel.commitAddress()
        }

        viewModel.undoManager.undo()

        #expect(viewModel.script.url == nil)
        #expect(viewModel.address.isEmpty)
    }

    @Test func theInspectorsTimingMovesAndResizesWithinTheLane() {
        let viewModel = makeViewModel()
        viewModel.addPointerClip(.hover)

        viewModel.selectionStart = 3
        #expect(viewModel.script.pointer[0].range == 3..<4)
        viewModel.selectionLength = 2.5
        #expect(viewModel.script.pointer[0].range == 3..<5.5)
        viewModel.selectionStart = 20
        #expect(viewModel.script.pointer[0].range == 7.5..<10)
    }

    @Test func theLengthNeverCutsAClip() {
        let viewModel = makeViewModel()
        viewModel.seek(to: 6)
        viewModel.addPointerClip(.hover)

        viewModel.duration = 2
        #expect(viewModel.duration == 7)
        viewModel.duration = 500
        #expect(viewModel.duration == WebScript.maximumDuration)
    }

    @Test func deletesTheSelectedClip() {
        let viewModel = makeViewModel()
        viewModel.addPointerClip(.hover)

        viewModel.deleteSelection()

        #expect(viewModel.script.pointer.isEmpty)
        #expect(viewModel.selection == nil)
    }

    @Test func keepsTheScriptForNextTime() throws {
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }
        let viewModel = makeViewModel()
        viewModel.address = "example.com"
        viewModel.commitAddress()
        viewModel.addPointerClip(.hover)

        viewModel.close()

        let reopened = makeViewModel()
        #expect(reopened.script == viewModel.script)
        #expect(reopened.address == "https://example.com")
    }

    // MARK: - Agent

    private func agentScript(url: String = "https://buildonto.dev") throws -> WebScript {
        var script = WebScript()
        script.url = URL(string: url)
        script.duration = 8
        script.scrolls = [ScrollClip(range: 2..<4, offset: CGPoint(x: 0, y: 600))]
        return script
    }

    @Test func anAgentsPlanBecomesTheScriptAsOneUndoableStep() throws {
        let viewModel = makeViewModel()
        step(viewModel) { viewModel.addPointerClip(.hover) }
        let before = viewModel.script
        let planned = try agentScript()

        step(viewModel) { viewModel.adoptAgentScript(planned) }

        #expect(viewModel.script == planned)
        #expect(viewModel.selection == nil)
        #expect(!viewModel.isPicking)
        #expect(viewModel.address == "https://buildonto.dev")
        viewModel.undoManager.undo()
        #expect(viewModel.script == before)
    }

    @Test func anAgentsPlanPlaysAtOnce() throws {
        let viewModel = makeViewModel()

        viewModel.adoptAgentScript(try agentScript())

        #expect(viewModel.isPlaying)
        viewModel.togglePlayback()
        #expect(!viewModel.isPlaying)
    }

    @Test func playbackMovesThePlayheadInRealTimeUntilSomethingStopsIt() async throws {
        let viewModel = makeViewModel()
        viewModel.edit("Length") { $0.duration = 5 }

        viewModel.togglePlayback()
        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.isPlaying)
        #expect((0.2...1.5).contains(viewModel.playhead))

        viewModel.edit("Length") { $0.duration = 6 }
        #expect(!viewModel.isPlaying)

        viewModel.togglePlayback()
        viewModel.seek(to: 1)
        #expect(!viewModel.isPlaying)
        #expect(viewModel.playhead == 1)
    }

    @Test func playingFromTheEndStartsOver() async throws {
        let viewModel = makeViewModel()
        viewModel.edit("Length") { $0.duration = 2 }
        viewModel.seek(to: 2)

        viewModel.togglePlayback()

        #expect(viewModel.isPlaying)
        #expect(viewModel.playhead < 0.5)
        viewModel.stopPlaying()
    }

    @Test func whatAnAgentFoundLightsUpOnlyOnThisPage() throws {
        let viewModel = makeViewModel()
        viewModel.adoptAgentScript(try agentScript())
        let box = PageInspection.Box(left: 10, top: 20, width: 100, height: 30)
        let below = PageInspection.Box(left: 10, top: 2000, width: 100, height: 30)
        var page = PageInspection(
            title: "Onto", url: "https://buildonto.dev/", viewport: .init(width: 1440, height: 900), pageHeight: 3000,
            elements: [
                .init(selector: "a.pricing", role: "link", text: "Pricing", box: box),
                .init(selector: "footer a", role: "link", text: "Docs", box: below)
            ],
            truncated: false
        )

        viewModel.showAgentInspection(page)
        #expect(viewModel.agentHighlights == [box.rect])

        page.url = "https://example.com/"
        let other = makeViewModel()
        other.adoptAgentScript(try agentScript())
        other.showAgentInspection(page)
        #expect(other.agentHighlights.isEmpty)
    }

    @Test func newWebRecordingStartsBlankAndUndoBringsTheLastBack() throws {
        let viewModel = makeViewModel()
        let planned = try agentScript()
        step(viewModel) { viewModel.adoptAgentScript(planned) }
        let previous = viewModel.script

        step(viewModel) { viewModel.startNew() }

        #expect(viewModel.script == WebScript())
        #expect(viewModel.address.isEmpty)
        #expect(!viewModel.isPlaying)
        viewModel.undoManager.undo()
        #expect(viewModel.script == previous)
    }
}

