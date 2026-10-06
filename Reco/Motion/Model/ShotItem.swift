//
//  ShotItem.swift
//  Reco
//

import Foundation

/// One of a shot's items: a feature's text and UI, or a cascade's element.
nonisolated struct ShotItem: Codable, Equatable, Sendable {
    var text: String?

    /// A ``MotionAsset``'s id; coded `ui`.
    var asset: String?

    private enum CodingKeys: String, CodingKey {
        case text
        case asset = "ui"
    }
}
