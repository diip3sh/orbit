//
//  CursorShapeTracker.swift
//  Reco
//
//  Created by Diip3sh on 25.09.26.
//

import CoreGraphics
import Foundation

/// Collects the cursor's distinct images and when the cursor switched between them, for
/// ``InputTelemetry/cursorSprites`` and ``InputTelemetry/cursorShapes``.
///
/// Each image is stored once: its PNG is only encoded, and its kind looked up, the first time its
/// fingerprint is seen.
nonisolated struct CursorShapeTracker {

    /// What tells cursor images apart. Arrow, I-beam and pointing hand can share a size and
    /// hotspot, so the pixels are compared too.
    nonisolated struct Fingerprint: Equatable {
        /// The image's size in points.
        var size: CGSize

        /// The click point, in points from the image's top-left corner.
        var hotspot: CGPoint

        /// Raw pixels of the image's smallest bitmap: cheap to read and compare on every poll.
        var pixels: Data
    }

    private(set) var sprites: [InputTelemetry.CursorSprite] = []
    private(set) var shapes: [InputTelemetry.CursorShape] = []
    private var fingerprints: [Fingerprint] = []

    /// Standard cursors to recognise: a new image equal to one of them gets its kind.
    private let standardCursors: [(kind: CursorKind, fingerprint: Fingerprint)]

    init(standardCursors: [(kind: CursorKind, fingerprint: Fingerprint)] = []) {
        self.standardCursors = standardCursors
    }

    /// Records that the cursor showed `fingerprint` at `time`. Only changes are kept.
    /// - Parameter png: Encodes the image; only called for a fingerprint not seen before.
    mutating func record(_ fingerprint: Fingerprint, time: Double, png: () -> Data) {
        // ponytail: linear search, fine for the handful of cursors a recording shows
        let id: Int
        if let known = fingerprints.firstIndex(of: fingerprint) {
            id = known
        } else {
            id = sprites.count
            fingerprints.append(fingerprint)
            let kind = standardCursors.first { $0.fingerprint == fingerprint }?.kind
            sprites.append(.init(id: id, kind: kind, size: fingerprint.size, hotspot: fingerprint.hotspot, png: png()))
        }

        guard id != shapes.last?.sprite else { return }
        shapes.append(.init(time: time, sprite: id))
    }
}
