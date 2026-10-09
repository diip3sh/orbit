//
//  StylePresetTests.swift
//  RecoTests
//
//  Created by Diip3sh on 08.10.26.
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

struct StylePresetTests {

    /// A project with content and a look unlike the defaults.
    private static func styledProject() -> EditorProject {
        var project = EditorProject()
        project.cuts = [1..<2]
        project.splits = [1, 2]
        project.zooms = [ZoomSegment(range: 3..<5, focus: .followCursor)]
        project.masks = [MaskSegment(range: 0..<1)]
        project.crop = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        project.audio.clickVolume = 0.5
        project.canvas.apply(GradientPreset.all[3])
        project.canvas.padding = 0.2
        project.clickHighlights.effect = .ripple
        project.keystrokes.showsAllKeys = true
        project.cursor.appearance = .dot
        project.zoomMotion = .fast
        project.motionBlur = 0.6
        return project
    }

    @Test func appliedTakesTheLookAndKeepsTheContent() {
        let styled = Self.styledProject()
        let preset = StylePreset(name: "Studio", of: styled)
        var other = EditorProject()
        other.cuts = [4..<6]
        other.zooms = [ZoomSegment(range: 0..<1, scale: 3, focus: .followCursor)]
        other.audio.clickVolume = 1

        let applied = preset.applied(to: other)

        #expect(applied.canvas == styled.canvas)
        #expect(applied.clickHighlights == styled.clickHighlights)
        #expect(applied.keystrokes == styled.keystrokes)
        #expect(applied.cursor == styled.cursor)
        #expect(applied.zoomMotion == .fast)
        #expect(applied.motionBlur == 0.6)
        #expect(applied.cuts == other.cuts)
        #expect(applied.zooms == other.zooms)
        #expect(applied.audio == other.audio)
        #expect(applied.crop == other.crop)
        #expect(preset.matches(applied))
        #expect(!preset.matches(other))
    }

    @Test func aFileRoundTrips() throws {
        let preset = StylePreset(name: "Studio", of: Self.styledProject())
        let data = try JSONEncoder().encode(preset)

        let read = try JSONDecoder().decode(StylePreset.self, from: data)

        #expect(read == preset)
        #expect(read.version == StylePreset.currentVersion)
    }

    @Test func missingSettingsTakeTheirDefaults() throws {
        let data = Data(#"{"version": 1, "name": "Bare"}"#.utf8)

        let read = try JSONDecoder().decode(StylePreset.self, from: data)

        #expect(read.name == "Bare")
        #expect(read.matches(EditorProject()))
    }

    @Test func anotherVersionIsRefused() {
        let data = Data(#"{"version": 2, "name": "Future"}"#.utf8)

        #expect(throws: UnsupportedVersionError(version: 2)) {
            try JSONDecoder().decode(StylePreset.self, from: data)
        }
    }
}

struct StylePresetStoreTests {

    private let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)

    @Test func savedStylesAreListedByNameAndReplacedByName() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        var project = EditorProject()
        project.motionBlur = 0.3
        let zebra = StylePreset(name: "zebra", of: EditorProject())
        let apple = StylePreset(name: "Apple", of: project)

        try StylePresetStore.save(zebra, in: folder)
        try StylePresetStore.save(apple, in: folder)
        #expect(StylePresetStore.list(in: folder) == [apple, zebra])

        var again = project
        again.motionBlur = 1
        try StylePresetStore.save(StylePreset(name: "Apple", of: again), in: folder)
        let listed = StylePresetStore.list(in: folder)
        #expect(listed.count == 2)
        #expect(listed.first?.motionBlur == 1)

        try StylePresetStore.delete(zebra, in: folder)
        #expect(StylePresetStore.list(in: folder).map(\.name) == ["Apple"])
    }

    @Test func fileNamesHoldTheStylesName() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let preset = StylePreset(name: "Talk: Intro/Outro", of: EditorProject())

        let url = try StylePresetStore.save(preset, in: folder)

        #expect(url.lastPathComponent == "Talk- Intro-Outro.recostyle")
        #expect(url == StylePresetStore.url(of: preset, in: folder))
        #expect(try StylePresetStore.read(from: url) == preset)
    }

    @Test func unreadableFilesAreSkippedAndReportedWhenAsked() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let broken = folder.appending(path: "Broken.recostyle")
        try Data("not json".utf8).write(to: broken)
        try StylePresetStore.save(StylePreset(name: "Fine", of: EditorProject()), in: folder)

        #expect(StylePresetStore.list(in: folder).map(\.name) == ["Fine"])
        #expect(throws: (any Error).self) {
            try StylePresetStore.read(from: broken)
        }
    }

    @Test func anEmptyFolderListsNothing() {
        #expect(StylePresetStore.list(in: folder).isEmpty)
    }
}

@MainActor
struct EditorViewModelStyleTests {

    @Test func applyingAStyleIsOneUndoStepThatKeepsTheContent() {
        let viewModel = EditorViewModel(videoURL: URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov"))
        // Edits in one run loop pass would otherwise share an undo group
        viewModel.undoManager.groupsByEvent = false
        viewModel.undoManager.beginUndoGrouping()
        viewModel.edit("Cut") { $0.cuts = [1..<2] }
        viewModel.undoManager.endUndoGrouping()
        var look = EditorProject()
        look.cursor.appearance = .white
        look.motionBlur = 0.5
        let preset = StylePreset(name: "Clean", of: look)
        viewModel.stylePresets = [preset]
        #expect(viewModel.currentStyle == nil)

        viewModel.undoManager.beginUndoGrouping()
        viewModel.apply(preset)
        viewModel.undoManager.endUndoGrouping()

        #expect(viewModel.project.cursor.appearance == .white)
        #expect(viewModel.project.motionBlur == 0.5)
        #expect(viewModel.project.cuts == [1..<2])
        #expect(viewModel.currentStyle == preset)
        #expect(viewModel.undoManager.undoActionName == "Apply Style")
        viewModel.undoManager.undo()
        #expect(viewModel.project.cursor.appearance == .recorded)
        #expect(viewModel.project.cuts == [1..<2])
        #expect(viewModel.currentStyle == nil)
    }
}
