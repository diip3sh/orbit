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

    @Test func changingAShotsLayerOverridesItByID() async throws {
        let (url, _) = try MotionTestBundle.makeGrammar(scale: 8)
        defer { try? FileManager.default.removeItem(at: url) }
        let viewModel = MotionEditorViewModel(bundleURL: url)
        await viewModel.load()

        viewModel.selectedLayer = "title.detail"
        #expect(viewModel.layer?.moves.map(\.kind) == [.fadeUp])
        viewModel.layer?.moves[0].duration = 0.8

        #expect(viewModel.document?.scenes[0].layers.map(\.id) == ["title.detail"])
        #expect(viewModel.layer?.moves[0].duration == 0.8)
        #expect(viewModel.laidOutScene?.layers.map(\.id) == ["title.headline", "title.detail"])

        // Saved once edits settle
        await viewModel.close()
        #expect(try await MotionStore.read(url).scenes[0].layers.first?.moves.first?.duration == 0.8)
    }
}
