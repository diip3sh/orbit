//
//  WebTarget.swift
//  Reco
//

import CoreGraphics

/// What a pointer clip aims at: an element found by its selector, or else a point in the viewport.
nonisolated struct WebTarget: Codable, Equatable, Sendable {

    /// A CSS selector for the element, made when it was picked, or `nil` for ``point`` alone.
    var selector: String?

    /// Where in the element's box the cursor goes, as fractions of its width and height from its
    /// top-left corner: where it was picked.
    var anchor = CGPoint(x: 0.5, y: 0.5)

    /// Where the target was in the viewport when picked, in CSS pixels from its top-left corner. Used
    /// when the selector matches nothing.
    var point: CGPoint

    /// Where the cursor goes, given the element's box in the viewport when the selector matched one.
    func location(elementFrame: CGRect?) -> CGPoint {
        guard let frame = elementFrame else { return point }
        return CGPoint(x: frame.minX + anchor.x * frame.width, y: frame.minY + anchor.y * frame.height)
    }
}
