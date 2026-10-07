//
//  SystemWallpaperTests.swift
//  RecoTests
//
//  Created by Diip3sh on 08.10.26.
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

struct SystemWallpaperTests {

    @Test func offersOnlyHEICPicturesInNaturalOrder() {
        let names = ["Big Sur.madesktop", ".thumbnails", "Solid Colors", "Sonoma.heic", "iMac Blue.heic", "Mac Blue.HEIC"]

        #expect(SystemWallpaper.pictureNames(in: names) == ["iMac Blue.heic", "Mac Blue.HEIC", "Sonoma.heic"])
    }

    @Test func listsWhatHasAPictureOnDiskWithItsThumbnail() async throws {
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
        let thumbnails = folder.appending(path: ".thumbnails")
        try FileManager.default.createDirectory(at: thumbnails, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let picture = InputTelemetry.CursorSprite.drawn(pixels: CGSize(width: 40, height: 30), size: .zero) {
            $0.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
            $0.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }.png
        // ImageIO sniffs the bytes, not the name
        try picture.write(to: folder.appending(path: "A.heic"))
        try picture.write(to: thumbnails.appending(path: "A.heic"))
        try Data("not a picture".utf8).write(to: folder.appending(path: "B.heic"))

        let wallpapers = await SystemWallpaper.installed(in: folder)

        #expect(wallpapers.map(\.name) == ["A"])
        #expect(wallpapers.first?.url == folder.appending(path: "A.heic"))
        #expect(wallpapers.first?.thumbnail.width == 40)
    }
}
