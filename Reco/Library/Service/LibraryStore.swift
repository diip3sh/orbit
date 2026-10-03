//
//  LibraryStore.swift
//  Reco
//

import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The Library's files (spec 0010): what's in the recordings and screenshot folders, their pictures,
/// and moving them to the Trash.
nonisolated enum LibraryStore {

    /// Everything Reco made in the two folders, newest first. A folder that doesn't exist yet has none.
    @concurrent
    static func items(recordings: URL, screenshots: URL) async throws -> [LibraryItem] {
        let recordingFiles = try contents(of: recordings)
        // Both may be one folder: it's read once, so nothing is listed twice
        let screenshotFiles = screenshots.standardizedFileURL == recordings.standardizedFileURL ? recordingFiles : try contents(of: screenshots)
        let movies = recordingFiles.compactMap { file in
            LibraryItem.recordingKind(of: file.url, contentType: file.type).map { LibraryItem(url: file.url, kind: $0, date: file.date) }
        }
        let shots = screenshotFiles
            .filter { LibraryItem.isScreenshot($0.url, contentType: $0.type) }
            .map { LibraryItem(url: $0.url, kind: .screenshot, date: $0.date) }
        return (movies + shots).sorted { $0.date > $1.date }
    }

    /// Moves `item` and its companions to the Trash, where the user can put them back. `remove` is
    /// how one file goes, for tests: an app can't list the Trash to clean up after them.
    @concurrent
    static func trash(
        _ item: LibraryItem, remove: @Sendable (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }
    ) async throws {
        try remove(item.url)
        for companion in item.companions where FileManager.default.fileExists(atPath: companion.path(percentEncoded: false)) {
            try? remove(companion)
        }
    }

    /// A picture of `item` at most `maximumSize` pixels: a movie's first frame, a screenshot shrunk.
    @concurrent
    static func thumbnail(of item: LibraryItem, maximumSize: CGSize) async -> CGImage? {
        guard item.isMovie else {
            guard let source = CGImageSourceCreateWithURL(item.url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: max(maximumSize.width, maximumSize.height),
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: item.url))
        generator.maximumSize = maximumSize
        generator.appliesPreferredTrackTransform = true
        return try? await generator.image(at: .zero).image
    }

    private static func contents(of folder: URL) throws -> [(url: URL, type: UTType?, date: Date)] {
        let keys: [URLResourceKey] = [.contentTypeKey, .creationDateKey]
        let urls: [URL]
        do {
            urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys, options: .skipsHiddenFiles)
        } catch CocoaError.fileReadNoSuchFile {
            return []
        }
        return urls.map { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            return (url, values?.contentType, values?.creationDate ?? .distantPast)
        }
    }
}
