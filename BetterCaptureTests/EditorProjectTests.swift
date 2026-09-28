//
//  EditorProjectTests.swift
//  BetterCaptureTests
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation
import Testing
@testable import BetterCapture

struct EditorProjectTests {

    @Test func roundTripsThroughJSON() throws {
        var project = EditorProject(cuts: [0..<1.5, 10..<12.25])
        project.clickHighlights.buttons = .left
        project.keystrokes.showsAllKeys = true

        let data = try JSONEncoder().encode(project)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["version"] as? Int == 1)
        #expect(try JSONDecoder().decode(EditorProject.self, from: data) == project)
    }

    @Test func readsAVersion1FileWrittenBeforeStylesWithDefaults() throws {
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

    @Test func fileSitsNextToTheVideoWithTheSameBaseName() {
        let video = URL(filePath: "/Users/me/Movies/BetterCapture_2026-09-26-10.00.00.mov")
        #expect(EditorProject.fileURL(for: video).path() == "/Users/me/Movies/BetterCapture_2026-09-26-10.00.00.edit.json")
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
