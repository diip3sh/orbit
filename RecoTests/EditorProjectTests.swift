//
//  EditorProjectTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

struct EditorProjectTests {

    @Test func roundTripsThroughJSON() throws {
        var project = EditorProject(cuts: [0..<1.5, 10..<12.25], splits: [5])
        project.zooms = [
            ZoomSegment(range: 2..<4, focus: .followCursor),
            ZoomSegment(range: 5..<7, scale: 1.5, focus: .fixed(center: CGPoint(x: 0.25, y: 0.75)), isAutomatic: true)
        ]
        project.clickHighlights.buttons = .left
        project.keystrokes.showsAllKeys = true
        project.cursor.smoothing = .mellow
        project.cursor.hidesWhenIdle = true
        project.cursor.appearance = .dot
        project.cursor.alwaysUsesArrow = true
        project.cursor.loops = true
        project.clickHighlights.effect = .ripple
        project.audio.clickVolume = 0.4
        project.audio.background = BackgroundAudio(bookmark: Data([1, 2, 3]), name: "Song", track: .init(volume: 0.2, isMuted: true))
        project.zoomMotion = .fast
        project.motionBlur = 0.6
        project.cursor.smoothing = .off
        project.canvas.aspect = .portrait
        project.canvas.background = .image
        project.canvas.imageBookmark = Data([1, 2, 3])
        project.canvas.backgroundBlur = 0.4
        project.canvas.borderWidth = 0.01
        project.canvas.borderColor = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)
        project.audio[track: 1].isMuted = true
        project.masks = [MaskSegment(range: 1..<2, rect: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4), kind: .pixelate)]

        let data = try JSONEncoder().encode(project)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["version"] as? Int == 1)
        #expect(try JSONDecoder().decode(EditorProject.self, from: data) == project)
    }

    @Test func readsAVersion1FileWrittenBeforeLaterSettingsWithDefaults() throws {
        let json = #"{ "version": 1, "cuts": [[1, 2]] }"#

        let project = try JSONDecoder().decode(EditorProject.self, from: Data(json.utf8))

        #expect(project == EditorProject(cuts: [1..<2]))
        #expect(project.motionBlur == 0)
    }

    @Test func rejectsAnUnknownVersion() {
        let json = #"{ "version": 2, "cuts": [] }"#

        #expect(throws: UnsupportedVersionError(version: 2)) {
            try JSONDecoder().decode(EditorProject.self, from: Data(json.utf8))
        }
    }

    @Test func fileSitsNextToTheVideoWithTheSameBaseName() {
        let video = URL(filePath: "/Users/me/Movies/Reco_2026-09-26-10.00.00.mov")
        #expect(EditorProject.fileURL(for: video).path() == "/Users/me/Movies/Reco_2026-09-26-10.00.00.edit.json")
    }

    @Test func storeWritesAndReadsBack() async throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let video = folder.appending(path: "recording.mov")
        let project = EditorProject(cuts: [2..<3])

        #expect(try await ProjectStore.read(for: video) == nil)
        try await ProjectStore.write(project, for: video)
        #expect(try await ProjectStore.read(for: video) == project)
    }

    @Test func readsTheClickSwitchOfProjectsSavedBeforeEffects() throws {
        func effect(_ json: String) throws -> ClickHighlightStyle.Effect {
            try JSONDecoder().decode(ClickHighlightStyle.self, from: Data(json.utf8)).effect
        }

        #expect(try effect(#"{ "isEnabled": false, "size": 30 }"#) == .off)
        #expect(try effect(#"{ "isEnabled": true }"#) == .circle)
        #expect(try effect(#"{ "isEnabled": false, "effect": "ripple" }"#) == .ripple)
        #expect(try JSONDecoder().decode(ClickHighlightStyle.self, from: Data(#"{ "isEnabled": false, "size": 30 }"#.utf8)).size == 30)
    }

    @Test func readsCursorAndAudioSettingsSavedBeforeTheNewOnesWithDefaults() throws {
        let cursor = try JSONDecoder().decode(
            CursorStyle.self, from: Data(#"{ "isEnabled": false, "size": 2, "smoothing": "fast", "animatesClicks": false, "hidesWhenIdle": true }"#.utf8)
        )
        var expected = CursorStyle()
        expected.isEnabled = false
        expected.size = 2
        expected.smoothing = .fast
        expected.animatesClicks = false
        expected.hidesWhenIdle = true
        #expect(cursor == expected)
        #expect(cursor.appearance == .recorded && !cursor.alwaysUsesArrow && !cursor.loops)

        let audio = try JSONDecoder().decode(AudioMixSettings.self, from: Data(#"{ "tracks": [{ "volume": 0.5, "isMuted": true }] }"#.utf8))
        #expect(audio.tracks == [AudioMixSettings.Track(volume: 0.5, isMuted: true)])
        #expect(audio.clickVolume == 0 && audio.background == nil && !audio.addsAudio)
        #expect(AudioMixSettings(background: BackgroundAudio(bookmark: Data(), name: "Song")).addsAudio)
    }

    @Test func readsACanvasSavedBeforeBlurAndBorderWithDefaults() throws {
        let canvas = try JSONDecoder().decode(CanvasStyle.self, from: Data(#"{ "aspect": "1:1", "padding": 0.1, "background": "color" }"#.utf8))
        var expected = CanvasStyle()
        expected.aspect = .square
        expected.padding = 0.1
        expected.background = .color

        #expect(canvas == expected)
        #expect(canvas.backgroundBlur == 0 && canvas.borderWidth == 0)
        #expect(try JSONDecoder().decode(CanvasStyle.self, from: Data("{}".utf8)) == CanvasStyle())
    }

    @Test func theDefaultGradientIsSlateAndAPickedOneIsNoPreset() {
        var canvas = CanvasStyle()
        #expect(canvas.gradientPreset == .slate)

        canvas.gradientStart.red = 0.5
        #expect(canvas.gradientPreset == nil)
        #expect(Set(GradientPreset.all.map(\.name)).count == GradientPreset.all.count)
        #expect(GradientPreset.all.first == .slate)
    }
}
