//
//  ArrowOverlayStyle.swift
//  Reco
//

import CoreGraphics

/// How an arrow overlay looks and where it points. Its ends can point any way, inside the overlay's frame.
nonisolated struct ArrowOverlayStyle: Codable, Equatable, Sendable {

    var color = RGBAColor(red: 1, green: 0.27, blue: 0.23, alpha: 1)

    /// The line's width as a share of the shorter side of the video on the canvas.
    var strokeWidth = 0.008

    /// The tail, as fractions of the overlay's frame from its top-left corner.
    var start = CGPoint(x: 0, y: 1)

    /// The tip, the same way.
    var end = CGPoint(x: 1, y: 0)

    /// The range the inspector offers for ``strokeWidth``.
    static let strokeWidths = 0.002...0.03
}
