//
//  TextOverlayStyle.swift
//  Reco
//

import Foundation

/// What a text overlay says and how it looks. The size is a share of the video on the canvas, so it fits at every
/// export size.
nonisolated struct TextOverlayStyle: Codable, Equatable, Sendable {

    /// How the lines sit across the overlay's frame.
    nonisolated enum Alignment: String, CaseIterable, Codable, Sendable {
        case left, center, right

        var title: LocalizedStringResource {
            switch self {
            case .left: "Left"
            case .center: "Center"
            case .right: "Right"
            }
        }
    }

    var text = "Text"

    /// The text's size as a share of the shorter side of the video on the canvas.
    var size = 0.06

    var color = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)

    var backgroundColor = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)

    /// How opaque the box behind the text is, from 0 (no box) to 1.
    var backgroundOpacity = 0.6

    var isBold = true

    var alignment = Alignment.center

    /// The range the inspector offers for ``size``.
    static let sizes = 0.02...0.2
}
