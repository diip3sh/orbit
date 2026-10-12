//
//  ShotItem.swift
//  Reco
//

import CoreGraphics
import Foundation

/// One of a shot's items: a feature's text and UI, a cascade's element, or a macro's stop.
nonisolated struct ShotItem: Codable, Equatable, Sendable {
    var text: String?

    /// A ``MotionAsset``'s id; coded `ui`.
    var asset: String?

    /// What a macro's frame shows of the UI, in CSS pixels from its top-left corner, as `inspect_page`
    /// measures boxes: it may reach past the element, to the ground round a corner or to the results a
    /// field grows.
    var view: CGRect?

    private enum CodingKeys: String, CodingKey {
        case text, view
        case asset = "ui"
    }
}
