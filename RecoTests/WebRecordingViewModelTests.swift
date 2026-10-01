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
}
