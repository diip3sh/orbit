//
//  WebTakeTests.swift
//  RecoTests
//

import Foundation
import Testing
@testable import Reco

struct WebTakeTests {

    private let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

    private var movie: URL {
        folder.appending(path: "Reco_Web_1.mov")
    }

    @Test func isSavedNextToItsMovieAndReadBack() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var script = WebScript()
        script.url = URL(string: "https://example.com")
        let take = WebTake(script: script, conversation: [AgentChatMessage(role: .user, text: "Scroll down.")])

        try await take.write(for: movie)

        #expect(WebTake.fileURL(for: movie).lastPathComponent == "Reco_Web_1.web.json")
        #expect(try await WebTake.read(for: movie) == take)
    }

    @Test func aRecordingWithoutOneHasNone() async throws {
        #expect(try await WebTake.read(for: movie) == nil)
    }

    @Test func anotherVersionIsRefused() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var take = WebTake(script: WebScript())
        take.version = 2
        try await take.write(for: movie)

        await #expect(throws: UnsupportedVersionError(version: 2)) { try await WebTake.read(for: movie) }
    }
}
