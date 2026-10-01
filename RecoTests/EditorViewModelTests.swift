//
//  EditorViewModelTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

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

        viewModel.cursor.smoothing = .fast

        #expect(viewModel.project.cursor.smoothing == .fast)
        #expect(viewModel.undoManager.undoActionName == "Cursor")

        viewModel.canvas.aspect = .square

        #expect(viewModel.project.canvas.aspect == .square)
        #expect(viewModel.undoManager.undoActionName == "Canvas")
    }

    @Test func aChosenPictureBecomesTheBackgroundThroughABookmark() async throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let picture = folder.appending(path: "wide.png")
        // Wider than pictures are read
        try InputTelemetry.CursorSprite.drawn(pixels: CGSize(width: 5000, height: 10), size: .zero) {
            $0.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
            $0.fill(CGRect(x: 0, y: 0, width: 5000, height: 10))
        }.png.write(to: picture)
        let viewModel = EditorViewModel(videoURL: videoURL)

        viewModel.setBackgroundImage(picture)

        #expect(viewModel.project.canvas.background == .image)
        #expect(viewModel.undoManager.undoActionName == "Background Image")
        let bookmark = try #require(viewModel.project.canvas.imageBookmark)
        let image = try #require(await BackgroundImageLoader.image(from: bookmark))
        #expect(image.width == BackgroundImageLoader.maximumSize && image.height < 10)
        #expect(image.colorSpace?.name == CGColorSpace.sRGB)
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
        #expect(!viewModel.canDeleteSelection)

        viewModel.select(at: 0.7)
        #expect(viewModel.selection == .segment(0.5..<1))
        viewModel.deleteSelection()
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
        #expect(viewModel.selection == .segment(0..<1))
        #expect(!viewModel.canDeleteSelection)
        viewModel.deleteSelection()
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

    @Test func aNewProjectStartsWithAutomaticZoomsSavedOnlyAfterAnEdit() async throws {
        let video = try await writeRecording()
        defer { try? FileManager.default.removeItem(at: video.deletingLastPathComponent()) }
        // A click in the middle of a 32×24 pt display, recorded at 64×48 px
        var telemetry = InputTelemetry(capture: .init(kind: .display, videoSize: CGSize(width: 64, height: 48)), keystrokesAvailable: false)
        telemetry.geometry = [
            .init(time: 0, screenRect: CGRect(x: 0, y: 0, width: 32, height: 24), contentRect: CGRect(x: 0, y: 0, width: 32, height: 24), contentScale: 1, scaleFactor: 2)
        ]
        telemetry.clicks = [.init(time: 0.3, location: CGPoint(x: 16, y: 12), button: .left, isDown: true, clickCount: 1)]
        try JSONEncoder().encode(telemetry).write(to: InputTelemetry.sidecarURL(for: video))
        let viewModel = EditorViewModel(videoURL: video)

        await viewModel.load()

        #expect(viewModel.project.zooms.map(\.range) == [0..<1])
        #expect(viewModel.project.zooms.map(\.isAutomatic) == [true])
        await viewModel.close()
        #expect(!FileManager.default.fileExists(atPath: EditorProject.fileURL(for: video).path()))
    }

    @Test func addsAZoomAtThePlayheadThenChangesAndDeletesIt() async throws {
        let video = try await writeRecording()
        defer { try? FileManager.default.removeItem(at: video.deletingLastPathComponent()) }
        let viewModel = EditorViewModel(videoURL: video)
        await viewModel.load()
        #expect(viewModel.project.zooms.isEmpty)

        viewModel.playback.seek(to: 0.2)
        viewModel.addZoom()
        let zoom = try #require(viewModel.selectedZoom)
        #expect(viewModel.undoManager.undoActionName == "Add Zoom")
        // Up to the end, and on the centre without a cursor to follow
        #expect(zoom.range == 0.2..<1)
        #expect(zoom.focus == .fixed(center: CGPoint(x: 0.5, y: 0.5)))
        #expect(!viewModel.canAddZoom)

        viewModel.selectedZoom?.scale = 3
        #expect(viewModel.project.zooms.map(\.scale) == [3])
        #expect(viewModel.undoManager.undoActionName == "Zoom")
        #expect(viewModel.selection == .zoom(zoom.id))

        viewModel.deleteSelection()
        #expect(viewModel.project.zooms.isEmpty)
        #expect(viewModel.undoManager.undoActionName == "Delete Zoom")
        #expect(viewModel.selection == nil)
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
