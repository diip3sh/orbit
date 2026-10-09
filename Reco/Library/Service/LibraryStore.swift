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

    /// Everything Reco made in the folders, newest first. A folder that doesn't exist yet has none.
    /// - Parameter history: Screenshots nobody saved (spec 0012); one that's also in `screenshots` is listed from there.
    @concurrent
    static func items(recordings: URL, screenshots: URL, history: URL) async throws -> [LibraryItem] {
        let recordingFiles = try contents(of: recordings)
        // Both may be one folder: it's read once, so nothing is listed twice
        let screenshotFiles = screenshots.standardizedFileURL == recordings.standardizedFileURL ? recordingFiles : try contents(of: screenshots)
        let movies = recordingFiles.compactMap { file in
            LibraryItem.recordingKind(of: file.url, contentType: file.type).map { LibraryItem(url: file.url, kind: $0, date: file.date) }
        }
        let shots = screenshotFiles
            .filter { LibraryItem.isScreenshot($0.url, contentType: $0.type) }
            .map { LibraryItem(url: $0.url, kind: .screenshot, date: $0.date) }
        let saved = Set(shots.map(\.url.lastPathComponent))
        let kept = try contents(of: history)
            .filter { LibraryItem.isScreenshot($0.url, contentType: $0.type) && !saved.contains($0.url.lastPathComponent) }
            .map { LibraryItem(url: $0.url, kind: .screenshot, date: $0.date) }
        return (movies + shots + kept).sorted { $0.date > $1.date }
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

    /// Each item's width over height as it shows, read side by side; one that can't be read is left out.
    @concurrent
    static func aspectRatios(of items: [LibraryItem]) async -> [LibraryItem: Double] {
        await withTaskGroup { group in
            for item in items {
                group.addTask { (item, await aspectRatio(of: item)) }
            }
            var ratios: [LibraryItem: Double] = [:]
            for await (item, ratio) in group {
                ratios[item] = ratio
            }
            return ratios
        }
    }

    /// A screenshot's or GIF's pixels from its header, a movie's from its video track with its transform.
    private static func aspectRatio(of item: LibraryItem) async -> Double? {
        guard item.isMovie else {
            guard let source = CGImageSourceCreateWithURL(item.url as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Double,
                  let height = properties[kCGImagePropertyPixelHeight] as? Double,
                  width > 0, height > 0 else { return nil }
            // EXIF orientations 5 to 8 turn the picture a quarter
            let isTurned = (properties[kCGImagePropertyOrientation] as? Int ?? 1) >= 5
            return isTurned ? height / width : width / height
        }
        guard let track = try? await AVURLAsset(url: item.url).loadTracks(withMediaType: .video).first,
              let geometry = try? await track.load(.naturalSize, .preferredTransform) else { return nil }
        let shown = geometry.0.applying(geometry.1)
        guard shown.width != 0, shown.height != 0 else { return nil }
        return abs(shown.width / shown.height)
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
