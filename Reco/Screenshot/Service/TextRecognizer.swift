//
//  TextRecognizer.swift
//  Reco
//
//  Created by Diip3sh on 29.09.26.
//

import CoreGraphics
import Vision

/// Recognizes text in screenshots with Vision (roadmap C7)
nonisolated enum TextRecognizer {

    /// The image's text, one recognized line per line, top to bottom; empty when there is none.
    ///
    /// Vision's Swift `RecognizeTextRequest` (macOS 15) rather than `VNRecognizeTextRequest`: it is async
    /// and `Sendable`, so no request handler or completion bridging.
    @concurrent
    static func text(in image: CGImage) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        let observations = try await request.perform(on: image)
        return joined(observations.compactMap { observation in
            observation.topCandidates(1).first.map { (text: $0.string, boundingBox: observation.boundingBox.cgRect) }
        })
    }

    /// Lines top to bottom, then left to right, joined with newlines. Boxes are normalized with a
    /// bottom-left origin, as Vision reports them.
    ///
    /// ponytail: sorts by top edge, so side-by-side columns interleave line by line, and lines on one row
    /// whose tops differ slightly may swap. Group into rows and columns if that's reported.
    static func joined(_ lines: [(text: String, boundingBox: CGRect)]) -> String {
        lines
            .sorted { ($0.boundingBox.maxY, -$0.boundingBox.minX) > ($1.boundingBox.maxY, -$1.boundingBox.minX) }
            .map(\.text)
            .joined(separator: "\n")
    }
}
