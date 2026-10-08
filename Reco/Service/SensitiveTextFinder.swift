//
//  SensitiveTextFinder.swift
//  Reco
//

import CoreGraphics
import Vision

/// Finds private text in an image with Vision (spec 0004, N9), for masks in the editor and on screenshots.
nonisolated enum SensitiveTextFinder {

    /// Text this small, as a share of the image's height, is still read: 0.008 is 17 px at 2160. At Vision's default,
    /// `.fast` found nothing at 26 px on a 4K frame with 120 lines of text (measured for spec 0004).
    static let minimumTextHeight: Float = 0.008

    /// What each box grows by on every side, as a share of its height: Vision's boxes hug the glyphs.
    static let padding = 0.25

    /// The boxes of `image`'s private text as fractions of it from its top-left corner, padded and at least
    /// `minimumSize` a side.
    ///
    /// `.fast` took about 150 ms on a 4K frame and `.accurate` about 2 s, which matters at one frame a second.
    @concurrent
    static func boxes(in image: CGImage, level: RecognizeTextRequest.RecognitionLevel = .fast, minimumSize: Double) async throws -> [CGRect] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = level
        request.minimumTextHeightFraction = minimumTextHeight
        request.usesLanguageCorrection = false
        let observations = try await request.perform(on: image)
        return observations.flatMap { observation -> [CGRect] in
            guard let text = observation.topCandidates(1).first else { return [] }
            return SensitiveText.ranges(in: text.string).compactMap { range in
                text.boundingBox(for: range).map { box(fromVision: $0.boundingBox.cgRect, minimumSize: minimumSize) }
            }
        }
    }

    /// Vision's normalized box, bottom-left origin, as a padded box from the top-left, inside the image.
    static func box(fromVision normalized: CGRect, minimumSize: Double) -> CGRect {
        let inset = -normalized.height * padding
        let padded = CGRect(x: normalized.minX, y: 1 - normalized.maxY, width: normalized.width, height: normalized.height)
            .insetBy(dx: inset, dy: inset)
        let grown = padded.insetBy(dx: min(padded.width - minimumSize, 0) / 2, dy: min(padded.height - minimumSize, 0) / 2)
        return RegionDrag.clamped(grown.intersection(CGRect(x: 0, y: 0, width: 1, height: 1)), minimumSize: minimumSize)
    }
}
