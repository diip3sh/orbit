//
//  LibraryTests.swift
//  RecoTests
//

import AppKit
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Reco

@MainActor
struct LibraryTests {

    private let root = URL.temporaryDirectory.appending(path: "LibraryTests-\(UUID().uuidString)", directoryHint: .isDirectory)

    private func folder(_ name: String) throws -> URL {
        let url = root.appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Writes empty files `ageInSeconds` old.
    private func write(_ names: [(String, Double)], in folder: URL) throws {
        for (name, age) in names {
            let url = folder.appending(path: name)
            try Data().write(to: url)
            try FileManager.default.setAttributes([.creationDate: Date.now.addingTimeInterval(-age)], ofItemAtPath: url.path)
        }
    }

    @Test func eachFileIsTheKindItsNameAndTypeSay() {
        let movie = UTType.quickTimeMovie
        #expect(LibraryItem.recordingKind(of: URL(filePath: "/r/Reco_2026.mov"), contentType: movie) == .recording)
        #expect(LibraryItem.recordingKind(of: URL(filePath: "/r/Reco_Web_2026.mov"), contentType: movie) == .webRecording)
        #expect(LibraryItem.recordingKind(of: URL(filePath: "/r/Reco_Web_2026-edited.mp4"), contentType: .mpeg4Movie) == .export)
        #expect(LibraryItem.recordingKind(of: URL(filePath: "/r/Reco.telemetry.json"), contentType: .json) == nil)
        #expect(LibraryItem.isScreenshot(URL(filePath: "/d/Reco_Screenshot_2026.png"), contentType: .png))
        #expect(!LibraryItem.isScreenshot(URL(filePath: "/d/Screenshot 2026.png"), contentType: .png))
        #expect(!LibraryItem.isScreenshot(URL(filePath: "/d/Reco_Screenshot_notes.txt"), contentType: .plainText))
    }

    @Test func aRecordingTakesItsSidecarsAlong() {
        let item = LibraryItem(url: URL(filePath: "/r/Reco_Web_1.mov"), kind: .webRecording, date: .now)
        #expect(item.companions.map(\.lastPathComponent) == ["Reco_Web_1.telemetry.json", "Reco_Web_1.edit.json"])
        #expect(LibraryItem(url: URL(filePath: "/d/Reco_Screenshot_1.png"), kind: .screenshot, date: .now).companions.isEmpty)
    }

    @Test func listsBothFoldersNewestFirstLeavingOutOthersFiles() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let movies = try folder("Movies")
        let desktop = try folder("Desktop")
        try write([("Reco_old.mov", 60), ("Reco_Web_new.mov", 0), ("Reco_Web_new.telemetry.json", 0), ("Reco_old-edited.mp4", 30)], in: movies)
        try write([("Reco_Screenshot_a.png", 10), ("Screenshot 2026.png", 5), ("notes.txt", 1)], in: desktop)

        let items = try await LibraryStore.items(recordings: movies, screenshots: desktop)

        #expect(items.map(\.name) == ["Reco_Web_new", "Reco_Screenshot_a", "Reco_old-edited", "Reco_old"])
        #expect(items.map(\.kind) == [.webRecording, .screenshot, .export, .recording])
    }

    @Test func oneFolderForBothIsReadOnceAndFoldersNotMadeYetHaveNothing() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let shared = try folder("Shared")
        try write([("Reco_1.mov", 1), ("Reco_Screenshot_1.png", 0)], in: shared)

        #expect(try await LibraryStore.items(recordings: shared, screenshots: shared).count == 2)
        #expect(try await LibraryStore.items(recordings: root.appending(path: "none"), screenshots: root.appending(path: "none2")).isEmpty)
    }

    @Test func theViewModelFiltersOpensCopiesAndTrashes() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let movies = try folder("Movies")
        let desktop = try folder("Desktop")
        let tag = UUID().uuidString
        try write([("Reco_\(tag).mov", 2), ("Reco_\(tag).telemetry.json", 2), ("Reco_Web_\(tag).mov", 1)], in: movies)
        let png = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8, samplesPerPixel: 4,
                                                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)?
            .representation(using: .png, properties: [:]))
        try png.write(to: desktop.appending(path: "Reco_Screenshot_\(tag).png"))
        let pasteboard = NSPasteboard(name: .init("LibraryTests-\(tag)"))
        defer { pasteboard.releaseGlobally() }
        var openedMovie: URL?
        var openedFile: URL?
        let viewModel = LibraryViewModel(
            folders: { (movies, desktop) }, openMovie: { openedMovie = $0 }, openFile: { openedFile = $0 }, pasteboard: pasteboard,
            trashItem: { try await LibraryStore.trash($0) { try FileManager.default.removeItem(at: $0) } }
        )

        await viewModel.reload()

        #expect(viewModel.count(in: .all) == 3)
        #expect(viewModel.count(in: .webRecordings) == 1)
        viewModel.section = .screenshots
        let shot = try #require(viewModel.shown.first)
        viewModel.open(shot)
        #expect(openedFile == shot.url)
        viewModel.copy(shot)
        #expect(pasteboard.data(forType: .png) == png)
        await viewModel.loadThumbnail(for: shot)
        #expect(viewModel.thumbnails[shot.url]?.width == 4)

        viewModel.section = .all
        viewModel.search = "web_"
        let web = try #require(viewModel.shown.first)
        #expect(viewModel.shown.count == 1)
        viewModel.open(web)
        #expect(openedMovie == web.url)

        viewModel.search = ""
        let recording = try #require(viewModel.shown.first { $0.kind == .recording })
        await viewModel.trash(recording)
        #expect(viewModel.count(in: .recordings) == 0)
        #expect(!FileManager.default.fileExists(atPath: recording.url.path))
        #expect(!FileManager.default.fileExists(atPath: movies.appending(path: "Reco_\(tag).telemetry.json").path))
    }
}
