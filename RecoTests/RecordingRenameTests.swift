//
//  RecordingRenameTests.swift
//  RecoTests
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Reco

struct RecordingRenameTests {

    @Test(arguments: ["Demo", "My demo 2", "a.b", "Reco_Web_x", "edited"])
    func usableNamesHaveNoProblem(name: String) {
        #expect(RecordingRename.problem(with: name) == nil)
    }

    @Test(arguments: ["", "   ", "a/b", "a:b", ".hidden", String(repeating: "a", count: 201), "Demo-edited", " Demo-edited "])
    func unusableNamesSayWhy(name: String) {
        #expect(RecordingRename.problem(with: name) != nil)
    }

    @Test func aWebRecordingShowsItsNameWithoutThePrefix() {
        #expect(RecordingRename.displayName(of: URL(filePath: "/m/Reco_Web_2026-10-07.mov")) == "2026-10-07")
        #expect(RecordingRename.displayName(of: URL(filePath: "/m/Reco_2026-10-07.mov")) == "Reco_2026-10-07")
    }

    @Test func theMovieAndItsCompanionsMoveTogether() {
        let moves = RecordingRename.moves(of: URL(filePath: "/m/Old.mov"), to: "  New name ")

        #expect(moves.map(\.from.path) == ["/m/Old.mov", "/m/Old.telemetry.json", "/m/Old.edit.json"])
        #expect(moves.map(\.to.path) == ["/m/New name.mov", "/m/New name.telemetry.json", "/m/New name.edit.json"])
    }

    @Test func aWebRecordingKeepsItsPrefix() {
        let moves = RecordingRename.moves(of: URL(filePath: "/m/Reco_Web_Old.mov"), to: "New")

        #expect(moves.map(\.to.path) == ["/m/Reco_Web_New.mov", "/m/Reco_Web_New.telemetry.json", "/m/Reco_Web_New.edit.json"])
    }

    @Test func aRenamedRecordingIsListedAsTheSameKind() {
        let kind = { (name: String) in LibraryItem.recordingKind(of: URL(filePath: "/m/\(name).mov"), contentType: .movie) }
        let web = RecordingRename.moves(of: URL(filePath: "/m/Reco_Web_Old.mov"), to: "New")[0].to
        let plain = RecordingRename.moves(of: URL(filePath: "/m/Old.mov"), to: "New")[0].to

        #expect(kind(web.deletingPathExtension().lastPathComponent) == .webRecording)
        #expect(kind(plain.deletingPathExtension().lastPathComponent) == .recording)
    }
}
