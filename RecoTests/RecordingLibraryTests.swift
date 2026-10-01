//
//  RecordingLibraryTests.swift
//  RecoTests
//
//  Created by Diip3sh on 28.09.26.
//

import Foundation
import Testing
@testable import Reco

struct RecordingLibraryTests {

    @Test func listsVideosNewestFirstWithoutExports() async throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for (name, age) in [("old.mov", 60.0), ("new.mp4", 0), ("new-edited.mp4", 0), ("new.telemetry.json", 0), ("notes.txt", 0)] {
            let url = folder.appending(path: name)
            try Data().write(to: url)
            try FileManager.default.setAttributes([.creationDate: Date.now.addingTimeInterval(-age)], ofItemAtPath: url.path)
        }

        let recordings = try await RecordingLibrary.recordings(in: folder)

        #expect(recordings.map(\.name) == ["new", "old"])
    }

    @Test func aFolderNotMadeYetHasNone() async throws {
        #expect(try await RecordingLibrary.recordings(in: URL.temporaryDirectory.appending(path: UUID().uuidString)).isEmpty)
    }
}
