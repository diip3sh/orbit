//
//  EditorViewModelTests.swift
//  BetterCaptureTests
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation
import Testing
@testable import BetterCapture

@MainActor
struct EditorViewModelTests {

    /// A recording that doesn't exist, in the temporary folder where autosave may write its project.
    private let videoURL = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")

    @Test func anEditIsOneUndoStepThatCanBeRedone() {
        let viewModel = EditorViewModel(videoURL: videoURL)
        let undoManager = viewModel.undoManager
        undoManager.groupsByEvent = false

        undoManager.beginUndoGrouping()
        viewModel.edit("Cut") { $0.cuts = [1..<2] }
        undoManager.endUndoGrouping()

        #expect(undoManager.undoActionName == "Cut")
        undoManager.undo()
        #expect(viewModel.project.cuts.isEmpty)
        undoManager.redo()
        #expect(viewModel.project.cuts == [1..<2])
    }

    /// Makes a coalescing edit in its own undo group, as each event is in the app.
    private func edit(_ viewModel: EditorViewModel, _ actionName: String, size: Double) {
        viewModel.undoManager.groupsByEvent = false
        viewModel.undoManager.beginUndoGrouping()
        viewModel.edit(actionName, coalescing: true) { $0.clickHighlights.size = size }
        viewModel.undoManager.endUndoGrouping()
    }

    /// The click sizes that undoing everything goes through, each time it changes.
    private func sizesWhileUndoing(_ viewModel: EditorViewModel) -> [Double] {
        var sizes = [viewModel.project.clickHighlights.size]
        while viewModel.undoManager.canUndo {
            viewModel.undoManager.undo()
            if sizes.last != viewModel.project.clickHighlights.size {
                sizes.append(viewModel.project.clickHighlights.size)
            }
        }
        return Array(sizes.dropFirst())
    }

    @Test func coalescingEditsInQuickSuccessionAreOneUndoStep() {
        let viewModel = EditorViewModel(videoURL: videoURL)

        for size in [50.0, 60, 70] {
            edit(viewModel, "Size", size: size)
        }

        #expect(sizesWhileUndoing(viewModel) == [ClickHighlightStyle().size])
        viewModel.undoManager.redo()
        #expect(viewModel.project.clickHighlights.size == 70)
    }

    @Test func anotherEditOrAnUndoEndsCoalescing() {
        let viewModel = EditorViewModel(videoURL: videoURL)
        edit(viewModel, "Size", size: 50)
        edit(viewModel, "Other", size: 60)
        edit(viewModel, "Size", size: 70)

        viewModel.undoManager.undo()
        edit(viewModel, "Size", size: 80)

        #expect(sizesWhileUndoing(viewModel) == [60, 50, ClickHighlightStyle().size])
    }

    @Test func inspectorChangesAreEdits() {
        let viewModel = EditorViewModel(videoURL: videoURL)

        viewModel.keystrokes.showsAllKeys = true

        #expect(viewModel.project.keystrokes.showsAllKeys)
        #expect(viewModel.undoManager.undoActionName == "Keystrokes")
    }

    @Test func splittingThenCuttingTheSelectionLeavesItOut() async throws {
        let video = try await writeRecording()
        defer { try? FileManager.default.removeItem(at: video.deletingLastPathComponent()) }
        let viewModel = EditorViewModel(videoURL: video)
        await viewModel.load()

        viewModel.playback.seek(to: 0.5)
        viewModel.split()
        #expect(viewModel.project.splits == [0.5])
        #expect(viewModel.undoManager.undoActionName == "Split")
        #expect(!viewModel.canCutSelection)

        viewModel.select(at: 0.7)
        #expect(viewModel.selection == 0.5..<1)
        viewModel.cutSelection()
        #expect(viewModel.project.cuts == [0.5..<1])
        #expect(viewModel.undoManager.undoActionName == "Cut")
        #expect(viewModel.timeMap.outputDuration == 0.5)
        #expect(viewModel.selection == nil)
    }

    @Test func theLastPartLeftCantBeCut() async throws {
        let video = try await writeRecording()
        defer { try? FileManager.default.removeItem(at: video.deletingLastPathComponent()) }
        let viewModel = EditorViewModel(videoURL: video)
        await viewModel.load()

        viewModel.select(at: 0.5)
        #expect(viewModel.selection == 0..<1)
        #expect(!viewModel.canCutSelection)
        viewModel.cutSelection()
        #expect(viewModel.project.cuts.isEmpty)
    }

    @Test func splittingWhereThereIsAlreadyABoundaryDoesNothing() async throws {
        let video = try await writeRecording()
        defer { try? FileManager.default.removeItem(at: video.deletingLastPathComponent()) }
        let viewModel = EditorViewModel(videoURL: video)
        await viewModel.load()

        viewModel.split()
        #expect(!viewModel.undoManager.canUndo)
    }

    @Test func movingAnEdgeIsATrim() async throws {
        let video = try await writeRecording()
        defer { try? FileManager.default.removeItem(at: video.deletingLastPathComponent()) }
        let viewModel = EditorViewModel(videoURL: video)
        await viewModel.load()

        viewModel.moveStart(ofKeptRange: 0, to: 0.2)
        viewModel.moveEnd(ofKeptRange: 0, to: 0.9)

        #expect(viewModel.project.cuts == [0..<0.2, 0.9..<1])
        #expect(viewModel.undoManager.undoActionName == "Trim")
    }

    /// A 1 s recording at 30 fps in a folder of its own.
    private func writeRecording() async throws -> URL {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let video = folder.appending(path: "recording.mov")
        try await TestRecording.write(to: video, size: CGSize(width: 64, height: 48), frameCount: 30, frameRate: 30)
        return video
    }

    @Test func anEditThatChangesNothingIsNotAnUndoStep() {
        let viewModel = EditorViewModel(videoURL: videoURL)

        viewModel.edit("Nothing") { _ in }

        #expect(!viewModel.undoManager.canUndo)
    }
}
