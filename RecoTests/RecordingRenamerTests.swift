//
//  RecordingRenamerTests.swift
//  RecoTests
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation
import Testing
@testable import Reco

struct RecordingRenamerTests {

    private let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func write(_ names: String...) throws {
        for name in names {
            try Data(name.utf8).write(to: folder.appending(path: name))
        }
    }

    private func names() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path()).sorted()
    }

    @Test func movesTheMovieAndBothCompanions() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try write("Old.mov", "Old.telemetry.json", "Old.edit.json", "Other.mov")

        let url = try await RecordingRenamer.rename(folder.appending(path: "Old.mov"), to: "New")

        #expect(url.lastPathComponent == "New.mov")
        #expect(try names() == ["New.edit.json", "New.mov", "New.telemetry.json", "Other.mov"])
        #expect(try String(contentsOf: url, encoding: .utf8) == "Old.mov")
    }

    @Test func skipsCompanionsThatDontExist() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try write("Old.mov", "Old.edit.json")

        _ = try await RecordingRenamer.rename(folder.appending(path: "Old.mov"), to: "New")

        #expect(try names() == ["New.edit.json", "New.mov"])
    }

    @Test func refusesANameThatIsTaken() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try write("Old.mov", "Old.edit.json", "Taken.mov")

        await #expect(throws: RecordingRenamer.RenameError.self) {
            try await RecordingRenamer.rename(folder.appending(path: "Old.mov"), to: "Taken")
        }
        #expect(try names() == ["Old.edit.json", "Old.mov", "Taken.mov"])
    }

    @Test func refusesAnInvalidName() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try write("Old.mov")

        await #expect(throws: RecordingRenamer.RenameError.self) {
            try await RecordingRenamer.rename(folder.appending(path: "Old.mov"), to: "a/b")
        }
        #expect(try names() == ["Old.mov"])
    }

    @Test func aFailedMoveUndoesTheOnesBefore() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        // A file already at the telemetry's new name makes that move fail after the movie's succeeded
        try write("Old.mov", "Old.telemetry.json", "New.telemetry.json")

        await #expect(throws: (any Error).self) {
            try await RecordingRenamer.rename(folder.appending(path: "Old.mov"), to: "New")
        }
        #expect(try names() == ["New.telemetry.json", "Old.mov", "Old.telemetry.json"])
    }
}
