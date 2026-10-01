//
//  ScrollClip.swift
//  Reco
//

import CoreGraphics
import Foundation

/// A clip on the Scroll lane: the page scrolls from where the previous clip left it, or the top, to
/// ``offset`` over the clip.
nonisolated struct ScrollClip: Codable, Equatable, Sendable, TimelineClip {
    var id = UUID()
    var range: Range<Double>

    /// Where the page is scrolled to at the clip's end: the viewport's top-left corner in the page,
    /// in CSS pixels.
    var offset: CGPoint

    var easing = Easing.easeInOut

    static let minimumDuration = 0.2

    /// A clip added by hand lasts this long, if there's room.
    static let defaultDuration = 1.5
}
