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
    /// in CSS pixels. With a ``target``, where it was planned; a take aims again when the clip starts.
    var offset: CGPoint

    var easing = Easing.easeInOut

    /// The element the scroll brings into view, or `nil` for a scroll to ``offset``. Scripts saved
    /// before it decode without it.
    var target: Target?

    static let minimumDuration = 0.2

    /// A clip added by hand lasts this long, if there's room.
    static let defaultDuration = 1.5

    /// Where a ``Target`` ends up in the viewport.
    nonisolated enum Placement: String, Codable, Sendable {

        /// Near the viewport's top, like a heading scrolled to.
        case top

        /// Just into view, clear of the viewport's edges by ``Target/margin``, and only when it isn't
        /// already: before the cursor goes to it.
        case intoView
    }

    /// An element to scroll to, found again when the clip starts, so a page whose layout shifted (a
    /// banner closed, content loaded) or that a click replaced still scrolls to it.
    nonisolated struct Target: Codable, Equatable, Sendable {
        var selector: String
        var placement: Placement

        /// The share of the viewport's height kept between an element scrolled to and the viewport's
        /// edge. A guess that clears typical sticky headers (apple.com's is 44 of 900 px); not measured.
        static let margin = 0.15

        /// Where the page scrolls to so it shows the element at `box`, in viewport CSS pixels while
        /// the page is scrolled to `current`, kept inside a page `pageHeight` tall.
        func offset(showing box: CGRect, from current: CGPoint, viewport: CGSize, pageHeight: Double) -> CGPoint {
            let margin = Self.margin * viewport.height
            let top: Double
            switch placement {
            case .top:
                top = current.y + box.minY - margin
            case .intoView:
                // As little as it takes, as scrollIntoView's "nearest" does, so the view the agent
                // scrolled to stays as much as it can
                if box.height > viewport.height - 2 * margin {
                    // Too tall for that: its middle, where the cursor goes, in the middle
                    guard box.midY < margin || box.midY > viewport.height - margin else { return current }
                    top = current.y + box.midY - viewport.height / 2
                } else if box.minY < margin {
                    top = current.y + box.minY - margin
                } else if box.maxY > viewport.height - margin {
                    top = current.y + box.maxY - viewport.height + margin
                } else {
                    return current
                }
            }
            return CGPoint(x: current.x, y: min(max(top, 0), max(pageHeight - viewport.height, 0)))
        }
    }
}
