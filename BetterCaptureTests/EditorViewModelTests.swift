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

    @Test func anEditThatChangesNothingIsNotAnUndoStep() {
        let viewModel = EditorViewModel(videoURL: videoURL)

        viewModel.edit("Nothing") { _ in }

        #expect(!viewModel.undoManager.canUndo)
    }
}
