//
//  RecordingsViewModelTests.swift
//  RecoTests
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

@MainActor
struct RecordingsViewModelTests {

    @Test func listsTheFolderAndOpensTheChosenRecording() async throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try await TestRecording.write(to: folder.appending(path: "recording.mov"), size: CGSize(width: 64, height: 48), frameCount: 3, frameRate: 30)
        var opened: URL?
        let viewModel = RecordingsViewModel(folder: folder) { opened = $0 }
        #expect(viewModel.recordings == nil)

        await viewModel.reload()
        let recording = try #require(viewModel.recordings?.first)
        await viewModel.loadThumbnail(for: recording)
        viewModel.open(recording)

        #expect(viewModel.thumbnails[recording.url]?.width == 64)
        #expect(opened == recording.url)
    }
}
