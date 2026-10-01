//
//  ClickMarker.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import CoreGraphics

/// A click to highlight, placed when the render plan is built.
nonisolated struct ClickMarker: Equatable, Sendable {

    /// Source time of the press.
    var time: Double

    /// The click point in Core Image pixel space (bottom-left origin).
    var position: CGPoint

    /// The ring's diameter when fully grown, in pixels.
    var diameter: CGFloat

    /// The markers whose ring shows at `time`: pressed at most `duration` earlier.
    /// - Parameter markers: Sorted by time.
    static func active(in markers: [ClickMarker], at time: Double, duration: Double) -> ArraySlice<ClickMarker> {
        let first = markers.partitioningIndex { $0.time > time - duration }
        let end = markers.partitioningIndex { $0.time > time }
        return markers[first..<max(first, end)]
    }
}
