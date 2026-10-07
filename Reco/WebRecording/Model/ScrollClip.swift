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
    /// in CSS pixels. With a ``target``, where it was planned; the take aims again when the clip starts.
    var offset: CGPoint

    var easing = Easing.easeInOut

    /// The element the scroll brings into view, or `nil` for a scroll to ``offset``.
    var target: Target?

    /// Where a ``Target`` ends up in the viewport.
    nonisolated enum Placement: String, Codable, Sendable {

        /// Near the viewport's top, like a heading scrolled to.
        case top

        /// Just into view, clear of the viewport's edges by ``Target/topMargin``, and only when it
        /// isn't wholly in view already: before the cursor goes to it.
        case intoView
    }

    static let minimumDuration = 0.2

    /// A clip added by hand lasts this long, if there's room.
    static let defaultDuration = 1.5

    /// An element to scroll to, found again when the clip starts, so a page whose layout shifted (a
    /// banner closed, content loaded) or that a click replaced still scrolls to it.
    nonisolated struct Target: Codable, Equatable, Sendable {
        var selector: String
        var placement: Placement

        /// The share of the viewport's height left above an element scrolled to the top. A guess
        /// that clears typical sticky headers (apple.com's is 44 of 900 px); not measured.
        static let topMargin = 0.15

        /// Where the page scrolls to so it shows the element at `box`, in viewport CSS pixels while
        /// the page is scrolled to `current`, kept inside a page `pageHeight` tall.
        func offset(showing box: CGRect, from current: CGPoint, viewport: CGSize, pageHeight: Double) -> CGPoint {
            let top: Double
            switch placement {
            case .top:
                top = current.y + box.minY - Self.topMargin * viewport.height
            case .intoView:
                // As little as it takes, as scrollIntoView's "nearest" does, so the view the agent
                // scrolled to stays as much as it can
                let margin = Self.topMargin * viewport.height
                if box.height > viewport.height - 2 * margin {
                    // Too tall for that: its middle, where the cursor goes, in the middle
                    guard box.midY < margin || box.midY > viewport.height - margin else { return current }
                    top = current.y + box.midY - viewport.height / 2
                } else if box.minY < 0 {
                    top = current.y + box.minY - margin
                } else if box.maxY > viewport.height {
                    top = current.y + box.maxY - viewport.height + margin
                } else {
                    return current
                }
            }
            return CGPoint(x: current.x, y: min(max(top, 0), max(pageHeight - viewport.height, 0)))
        }
    }
}
