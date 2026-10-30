//
//  CameraFootageStore.swift
//  Reco
//

import AVFoundation
import CoreGraphics
import OSLog

/// Reads and writes a recording's camera files. The recording's folder must be accessible.
nonisolated enum CameraFootageStore {

    /// `<name>.camera.json`.
    private struct Sidecar: Codable {
        let offset: Double
    }

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "CameraFootageStore")

    /// The recording's footage, or `nil` when there's no movie or it has no readable video: the recording opens either
    /// way. A missing or unreadable offset leaves the footage starting with the recording.
    static func load(for videoURL: URL) async -> CameraFootage? {
        let movie = CameraFootage.movieURL(for: videoURL)
        guard FileManager.default.fileExists(atPath: movie.path(percentEncoded: false)) else { return nil }
        let asset = AVURLAsset(url: movie)
        do {
            guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                logger.error("\(movie.lastPathComponent) has no video")
                return nil
            }
            let (timeRange, naturalSize, transform) = try await track.load(.timeRange, .naturalSize, .preferredTransform)
            guard timeRange.duration > .zero else { return nil }
            let shown = naturalSize.applying(transform)
            let offset = readOffset(for: videoURL)
            return CameraFootage(
                url: movie, asset: asset, trackID: track.trackID, timeRange: timeRange,
                displaySize: CGSize(width: abs(shown.width), height: abs(shown.height)),
                orientation: CameraFootage.orientation(of: transform), offset: offset ?? 0, hasRecordedOffset: offset != nil
            )
        } catch {
            logger.error("Couldn't read \(movie.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    /// Writes where the footage starts on the recording's timeline.
    static func writeOffset(_ offset: Double, for videoURL: URL) throws {
        try JSONEncoder().encode(Sidecar(offset: offset)).write(to: CameraFootage.sidecarURL(for: videoURL), options: .atomic)
    }

    /// Makes a copy of `file`, a video chosen by the user, the recording's footage, starting with the recording. Throws,
    /// changing nothing, when it has no video.
    @concurrent
    static func install(_ file: URL, for videoURL: URL) async throws {
        guard try await !AVURLAsset(url: file).loadTracks(withMediaType: .video).isEmpty else { throw EditorError.noVideoTrack }
        let movie = CameraFootage.movieURL(for: videoURL)
        if file.standardizedFileURL != movie.standardizedFileURL {
            // Hidden, so the Library never lists it, and whole before it takes the name
            let copy = movie.deletingLastPathComponent().appending(path: ".\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: file, to: copy)
            do {
                if FileManager.default.fileExists(atPath: movie.path(percentEncoded: false)) {
                    _ = try FileManager.default.replaceItemAt(movie, withItemAt: copy)
                } else {
                    try FileManager.default.moveItem(at: copy, to: movie)
                }
            } catch {
                try? FileManager.default.removeItem(at: copy)
                throw error
            }
        }
        try writeOffset(0, for: videoURL)
    }

    /// The footage's first frame as it shows, at most `maximumSize` pixels, for the crop pad.
    @concurrent
    static func picture(of footage: CameraFootage, maximumSize: CGSize) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: footage.asset)
        generator.maximumSize = maximumSize
        generator.appliesPreferredTrackTransform = true
        return try? await generator.image(at: footage.timeRange.start).image
    }

    private static func readOffset(for videoURL: URL) -> Double? {
        let url = CameraFootage.sidecarURL(for: videoURL)
        do {
            return try JSONDecoder().decode(Sidecar.self, from: Data(contentsOf: url)).offset
        } catch {
            logger.error("No offset from \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }
}
