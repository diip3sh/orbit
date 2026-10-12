//
//  SystemWallpaper.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import CoreGraphics
import Foundation
import ImageIO

/// A picture macOS ships as a desktop picture, offered as a canvas background.
///
/// Measured on macOS 27.0.1 (M2): `/System/Library/Desktop Pictures` holds 13 full-size `.heic` files of
/// 6016×6016 px and 8.7–25 MB (iMac in 7 colors, Mac in 4, Radial Sky Blue, Sonoma), 138 thumbnails of
/// 214×130 px in `.thumbnails`, and 63 `.madesktop` plists, which only point to MobileAssets downloaded on
/// demand (none were: `AssetsV2/com_apple_MobileAsset_DesktopPicture` held the catalog alone). A thumbnail
/// stretched to a 2160 px canvas would be 16.6× enlarged, so thumbnails are only the grid's tiles and only
/// pictures with a full image on disk are offered. A picture is read like any chosen one, once, at most
/// 4096 px (`sips -Z 4096` took 0.49 s with re-encoding).
nonisolated struct SystemWallpaper: Identifiable, Sendable {
    // ponytail: downloaded `.madesktop` assets under AssetsV2 and `.wallpapers/Sonoma Horizon.heic` aren't offered;
    // add them when someone asks. Solid Colors duplicate the Color background and the aerials are videos.

    let url: URL
    let thumbnail: CGImage

    var id: URL { url }
    var name: String { url.deletingPathExtension().lastPathComponent }

    static let folder = URL(filePath: "/System/Library/Desktop Pictures", directoryHint: .isDirectory)

    /// The names in `fileNames` that are pictures, in the order tiles show them.
    static func pictureNames(in fileNames: [String]) -> [String] {
        fileNames
            .filter { !$0.hasPrefix(".") && $0.lowercased().hasSuffix(".heic") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// The wallpapers in `folder` with a picture on disk, with the thumbnail macOS made for each if there is one.
    @concurrent
    static func installed(in folder: URL = folder) async -> [SystemWallpaper] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
        return pictureNames(in: names).compactMap { name in
            let picture = folder.appending(path: name)
            let made = folder.appending(path: ".thumbnails").appending(path: name)
            let source = FileManager.default.fileExists(atPath: made.path(percentEncoded: false)) ? made : picture
            return thumbnail(of: source).map { SystemWallpaper(url: picture, thumbnail: $0) }
        }
    }

    /// `url` at most 256 px on the longer side.
    private static func thumbnail(of url: URL) -> CGImage? {
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 256
        ] as CFDictionary
        return CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, options) }
    }
}
