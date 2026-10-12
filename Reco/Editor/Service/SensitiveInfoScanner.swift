//
//  SensitiveInfoScanner.swift
//  Reco
//

import AVFoundation

/// Reads a recording's frames for private text (spec 0004, N9), off the main actor.
nonisolated enum SensitiveInfoScanner {

    /// Seconds between the frames read: at ~150 ms a 4K frame, 10 minutes take about 90 s.
    static let interval = 1.0

    /// Every ``interval`` through each of `ranges` from its start; cut parts aren't read.
    static func times(in ranges: [Range<Double>]) -> [Double] {
        ranges.flatMap { Array(stride(from: $0.lowerBound, to: $0.upperBound, by: interval)) }
    }

    /// The boxes in the frames nearest `times`, inside `crop` (pixels from the frame's top-left corner) and as
    /// fractions of it. `onProgress` gets the share done after each frame. A frame that can't be read has no sample;
    /// stops early when the calling task is cancelled.
    @concurrent
    static func samples(
        of source: EditorSource, at times: [Double], crop: CGRect, onProgress: @MainActor @Sendable (Double) -> Void
    ) async -> [SensitiveMasks.Sample] {
        let generator = AVAssetImageGenerator(asset: source.asset)
        // A frame within half the spacing is as good as the exact one and decodes far faster; each sample is placed
        // at the frame's own time
        let tolerance = CMTime(seconds: interval / 2, preferredTimescale: source.timescale)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        var samples: [SensitiveMasks.Sample] = []
        var done = 0
        for await result in generator.images(for: times.map { CMTime(seconds: $0, preferredTimescale: source.timescale) }) {
            guard !Task.isCancelled else { break }
            done += 1
            if let frame = try? result.image, let image = frame.cropping(to: crop),
               let boxes = try? await SensitiveTextFinder.boxes(in: image, minimumSize: MaskSegment.minimumSize) {
                samples.append(SensitiveMasks.Sample(time: (try? result.actualTime.seconds) ?? result.requestedTime.seconds, boxes: boxes))
            }
            await onProgress(Double(done) / Double(max(times.count, 1)))
        }
        return samples.sorted { $0.time < $1.time }
    }
}
