//
//  EditorViewModelBackgroundTests.swift
//  RecoTests
//
//  Created by Diip3sh on 08.10.26.
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

@MainActor
struct EditorViewModelBackgroundTests {

    @Test func aGradientPresetIsOneUndoStep() {
        let viewModel = EditorViewModel(videoURL: URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov"))
        let ocean = GradientPreset.all[3]

        viewModel.applyGradient(ocean)

        #expect(viewModel.project.canvas.gradientPreset == ocean)
        #expect(viewModel.undoManager.undoActionName == "Gradient")
        viewModel.undoManager.undo()
        #expect(viewModel.project.canvas.gradientPreset == .slate)
        #expect(!viewModel.undoManager.canUndo)
    }

    @Test func aWallpaperIsRingedOnceItsPictureIsRead() async throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let video = folder.appending(path: "recording.mov")
        try await TestRecording.write(to: video, size: CGSize(width: 64, height: 48), frameCount: 30, frameRate: 30)
        let picture = folder.appending(path: "wallpaper.png")
        try InputTelemetry.CursorSprite.drawn(pixels: CGSize(width: 40, height: 30), size: .zero) {
            $0.setFillColor(red: 0, green: 1, blue: 0, alpha: 1)
            $0.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }.png.write(to: picture)
        let viewModel = EditorViewModel(videoURL: video)
        await viewModel.load()
        let wallpaper = SystemWallpaper(url: picture.resolvingSymlinksInPath(), thumbnail: try .filled(width: 4, height: 3))
        #expect(!viewModel.isBackground(wallpaper))

        viewModel.setBackgroundImage(picture)

        for _ in 0..<500 where viewModel.backgroundImageURL == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(viewModel.backgroundImageURL == picture.resolvingSymlinksInPath())
        #expect(viewModel.isBackground(wallpaper))
        await viewModel.close()
    }
}
