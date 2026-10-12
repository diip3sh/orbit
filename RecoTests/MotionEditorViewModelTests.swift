//
//  MotionEditorViewModelTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

/// Editing a motion document in its window: undo, refused edits, a shot's layers.
@MainActor
struct MotionEditorViewModelTests {

    @Test func editsAreUndoneAndInvalidOnesRefused() async throws {
        let (url, document) = try MotionTestBundle.makeGrammar(scale: 8)
        defer { try? FileManager.default.removeItem(at: url) }
        let viewModel = MotionEditorViewModel(bundleURL: url)
        await viewModel.load()
        #expect(viewModel.document == document)

        viewModel.scene?.duration = 4
        #expect(viewModel.document?.scenes[0].duration == 4)
        viewModel.undoManager.undo()
        #expect(viewModel.document == document)

        // A title needs text
        viewModel.scene?.shot?.text = nil
        #expect(viewModel.document == document)
        await viewModel.close()
    }

    @Test func changingAShotLayersMovesKeepsItWhereTheShotPutsIt() async throws {
        let (url, _) = try MotionTestBundle.makeGrammar(scale: 8)
        defer { try? FileManager.default.removeItem(at: url) }
        let viewModel = MotionEditorViewModel(bundleURL: url)
        await viewModel.load()

        viewModel.selectedLayer = "title.detail"
        #expect(viewModel.layer?.moves.map(\.kind) == [.fadeUp])
        viewModel.layer?.moves[0].duration = 0.8

        #expect(viewModel.document?.scenes[0].layers.isEmpty == true)
        #expect(viewModel.document?.scenes[0].shotMoves["title.detail"]?.first?.duration == 0.8)
        #expect(viewModel.layer?.moves[0].duration == 0.8)
        #expect(viewModel.laidOutScene?.layers.map(\.id) == ["title.headline", "title.detail"])

        // Any other change copies the layer, which replaces the shot's by its id
        viewModel.layer?.opacity = 0.5
        #expect(viewModel.document?.scenes[0].layers.map(\.id) == ["title.detail"])

        // Saved once edits settle
        await viewModel.close()
        #expect(try await MotionStore.read(url).scenes[0].shotMoves["title.detail"]?.first?.duration == 0.8)
    }

    @Test func anAgentsEditIsOneUndoStepSavedAtOnce() async throws {
        let (url, document) = try MotionTestBundle.makeGrammar(scale: 8)
        defer { try? FileManager.default.removeItem(at: url) }
        let viewModel = MotionEditorViewModel(bundleURL: url)
        await viewModel.load()
        var edited = document
        edited.scenes[0].duration = 5
        edited.scenes[1].seam = .blurCut

        try await viewModel.apply(edited, actionName: "Agent Edit")
        #expect(try await MotionStore.read(url) == edited)
        #expect(viewModel.undoManager.undoActionName == "Agent Edit")
        viewModel.undoManager.undo()
        #expect(viewModel.document == document)
        await viewModel.close()
    }
}
