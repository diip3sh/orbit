//
//  PlannedCaption.swift
//  Reco
//

import CoreGraphics
import CoreImage

/// A caption ready to draw, placed on the canvas when the render plan is built.
nonisolated struct PlannedCaption: Sendable {

    /// A word's start in source seconds and where it is on the canvas.
    struct Word: Equatable, Sendable {
        var start: Double
        var rect: CGRect
    }

    /// When it shows, in source seconds.
    let range: Range<Double>

    /// The text's coverage, white where it's drawn. It's a single 8-bit channel, a quarter of an RGBA image and shared
    /// by both colors, so the word being said needs no second image (see ``FrameRenderer``).
    let mask: CIImage

    /// The box behind the text, or `nil` without one.
    let box: CIImage?

    /// In order.
    let words: [Word]

    /// The caption showing at source time `time`. A caption's parts in a cut never show, as no frame shows that time.
    /// - Parameter captions: Sorted and apart.
    static func visible(in captions: [PlannedCaption], at time: Double) -> PlannedCaption? {
        let next = captions.partitioningIndex { $0.range.lowerBound > time }
        guard next > 0, captions[next - 1].range.contains(time) else { return nil }
        return captions[next - 1]
    }

    /// The word being said at source time `time`: the last one started, which stays lit through a pause.
    func word(at time: Double) -> Word? {
        let next = words.partitioningIndex { $0.start > time }
        return next > 0 ? words[next - 1] : nil
    }
}
