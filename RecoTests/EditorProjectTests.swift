//
//  EditorProjectTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

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
        project.canvas.aspect = .portrait
        project.canvas.background = .image
        project.canvas.imageBookmark = Data([1, 2, 3])
        project.audio[track: 1].isMuted = true

        let data = try JSONEncoder().encode(project)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["version"] as? Int == 1)
        #expect(try JSONDecoder().decode(EditorProject.self, from: data) == project)
    }

    @Test func readsAVersion1FileWrittenBeforeLaterSettingsWithDefaults() throws {
        let json = #"{ "version": 1, "cuts": [[1, 2]] }"#

        let project = try JSONDecoder().decode(EditorProject.self, from: Data(json.utf8))

        #expect(project == EditorProject(cuts: [1..<2]))
    }

    @Test func rejectsAnUnknownVersion() {
        let json = #"{ "version": 2, "cuts": [] }"#

        #expect(throws: UnsupportedVersionError(version: 2)) {
            try JSONDecoder().decode(EditorProject.self, from: Data(json.utf8))
        }
    }

    @Test func aNewTakeKeepsTheLookButNotWhatBelongsToOneRecording() {
        var old = EditorProject(cuts: [0..<1], splits: [3])
        old.zooms = [ZoomSegment(range: 2..<4, focus: .followCursor)]
        old.canvas.aspect = .portrait
        old.cursor.size = 2
        old.clickHighlights.size = 80
        old.keystrokes.showsAllKeys = true
        old.audio[track: 0].isMuted = true
        let new = EditorProject(zooms: [ZoomSegment(range: 5..<7, focus: .followCursor)])

        let styled = new.styled(like: old)

        #expect(styled.canvas == old.canvas && styled.cursor == old.cursor)
        #expect(styled.clickHighlights == old.clickHighlights && styled.keystrokes == old.keystrokes)
        #expect(styled.cuts.isEmpty && styled.splits.isEmpty)
        #expect(styled.zooms == new.zooms && styled.audio == new.audio)
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
}
