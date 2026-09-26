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

    @Test func anEditThatChangesNothingIsNotAnUndoStep() {
        let viewModel = EditorViewModel(videoURL: videoURL)

        viewModel.edit("Nothing") { _ in }

        #expect(!viewModel.undoManager.canUndo)
    }
}
