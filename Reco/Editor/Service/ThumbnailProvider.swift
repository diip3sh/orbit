//
//  ThumbnailProvider.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation

/// Decodes the timeline's filmstrip images and the recordings' pictures, off the main actor.
nonisolated enum ThumbnailProvider {

    /// The first frame of the video at `url`, at most `maximumSize` pixels, or `nil` when it can't
    /// be decoded.
    @concurrent
    static func thumbnail(of url: URL, maximumSize: CGSize) async -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.maximumSize = maximumSize
        return try? await generator.image(at: .zero).image
    }

    /// One image per source time, each at most `maximumSize` pixels, or `nil` where decoding failed.
    /// Stops early when the calling task is cancelled.
    @concurrent
    static func thumbnails(of source: EditorSource, at times: [Double], maximumSize: CGSize) async -> [CGImage?] {
        let generator = AVAssetImageGenerator(asset: source.asset)
        generator.maximumSize = maximumSize

        // A frame within half the spacing is as good as the exact one and decodes far faster
        let spacing = times.count > 1 ? times[1] - times[0] : source.duration
        let tolerance = CMTime(seconds: spacing / 2, preferredTimescale: source.timescale)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        let requests = times.map { CMTime(seconds: $0, preferredTimescale: source.timescale) }
        let indices = Dictionary(zip(requests, requests.indices)) { first, _ in first }

        var images = [CGImage?](repeating: nil, count: times.count)
        for await result in generator.images(for: requests) {
            if let index = indices[result.requestedTime], let image = try? result.image {
                images[index] = image
            }
        }
        return images
    }
}
