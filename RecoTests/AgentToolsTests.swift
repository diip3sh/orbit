//
//  AgentToolsTests.swift
//  RecoTests
//

import Foundation
import ImageIO
import Testing
@testable import Reco

@MainActor
struct AgentToolsTests {

    private func tools(onRendered: @escaping (URL) -> Void = { _ in }) -> AgentTools {
        AgentTools(settings: SettingsStore(), onRendered: onRendered)
    }

    private func status(_ reply: AgentTools.Reply) throws -> RenderStatus {
        try JSONDecoder().decode(RenderStatus.self, from: Data(reply.text.utf8))
    }

    @Test func aPageThatCantBeLoadedFailsTheRenderWithAReason() async throws {
        var opened: [URL] = []
        let tools = tools { opened.append($0) }

        // Nothing listens on port 1, so the load is refused at once
        let reply = await tools.call("record_page", arguments: Data(##"{"url":"http://localhost:1","steps":[{"action":"hover","selector":"#a"}]}"##.utf8))

        let failed = try status(reply)
        #expect(reply.isError)
        #expect(failed.status == .failed)
        #expect(failed.error?.contains("couldn't be loaded") == true)
        #expect(failed.movie == nil)
        #expect(opened.isEmpty)
        #expect(tools.job == failed)
    }

    @Test func renderStatusReportsTheLatestRenderAndRefusesOthers() async throws {
        let tools = tools()
        let failed = try status(await tools.call("record_page", arguments: Data(#"{"url":"http://localhost:1","steps":[]}"#.utf8)))

        let known = await tools.call("render_status", arguments: Data(#"{"render_id":"\#(failed.renderID)"}"#.utf8))
        let unknown = await tools.call("render_status", arguments: Data(#"{"render_id":"other"}"#.utf8))

        #expect(try status(known) == failed)
        #expect(unknown.isError)
        #expect(unknown.text.contains("record_page"))
    }

    @Test func aFailedRenderDoesntBlockTheNextOne() async throws {
        let tools = tools()
        let first = try status(await tools.call("record_page", arguments: Data(#"{"url":"http://localhost:1","steps":[]}"#.utf8)))

        let second = try status(await tools.call("record_page", arguments: Data(#"{"url":"http://localhost:1","steps":[]}"#.utf8)))

        #expect(second.renderID != first.renderID)
        #expect(second.status == .failed)
    }

    @Test func exportsARecordingAsItWouldOpenInTheEditorAndReportsTheFile() async throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let movie = folder.appending(path: "take.mov")
        try await TestRecording.write(to: movie, size: CGSize(width: 320, height: 240), frameCount: 15, frameRate: 30)
        let tools = tools()

        let reply = await tools.call("export_recording", arguments: Data(#"{"movie":"\#(movie.path(percentEncoded: false))","format":"gif"}"#.utf8))

        let status = try JSONDecoder().decode(ExportStatus.self, from: Data(reply.text.utf8))
        #expect(!reply.isError)
        #expect(status == ExportStatus(status: .done, progress: 1, file: folder.appending(path: "take-edited.gif").path(percentEncoded: false)))
        let gif = try #require(CGImageSourceCreateWithURL(folder.appending(path: "take-edited.gif") as CFURL, nil))
        // The default canvas at its own size: 240 px is under a GIF's 540
        #expect(CGImageSourceGetCount(gif) >= 1)
        #expect(CGImageSourceCreateImageAtIndex(gif, 0, nil)?.height == 240)
    }

    @Test func exportRefusesWhatIsNotARecordingOrAFormat() async {
        let tools = tools()

        let missing = await tools.call("export_recording", arguments: Data(#"{"movie":"/nowhere/take.mov"}"#.utf8))
        let relative = await tools.call("export_recording", arguments: Data(#"{"movie":"take.mov"}"#.utf8))
        let format = await tools.call("export_recording", arguments: Data(#"{"movie":"/bin/sh","format":"avi"}"#.utf8))
        let unreadable = await tools.call("export_recording", arguments: Data(#"{"movie":"/bin/sh"}"#.utf8))

        #expect(missing.isError && missing.text.contains("record_page"))
        #expect(relative.isError)
        #expect(format.isError && format.text.contains("gif, h264, hevc"))
        #expect(unreadable.isError && unreadable.text.contains(#""status":"failed""#))
    }

    @Test func badArgumentsAreErrorsTheAgentCanActOn() async {
        let tools = tools()

        let wrongType = await tools.call("record_page", arguments: Data(#"{"url":"example.com","steps":"click"}"#.utf8))
        let notJSON = await tools.call("inspect_page", arguments: Data("nope".utf8))
        let invalid = await tools.call("inspect_page", arguments: Data(#"{"url":"example.com","viewport":"watch"}"#.utf8))
        let unknown = await tools.call("format_disk", arguments: Data("{}".utf8))

        #expect(wrongType.isError && wrongType.text.contains("steps"))
        #expect(notJSON.isError)
        #expect(invalid.isError && invalid.text.contains("desktop"))
        #expect(unknown.isError && unknown.text.contains("inspect_page"))
        #expect(tools.job == nil)
    }
}
