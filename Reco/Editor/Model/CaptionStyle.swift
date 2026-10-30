//
//  CaptionStyle.swift
//  Reco
//

import Foundation

/// How captions look. Sizes are shares of the video on the canvas, so they fit at every export size.
nonisolated struct CaptionStyle: Codable, Equatable, Sendable {

    /// Where captions sit on the video.
    nonisolated enum Position: String, CaseIterable, Codable, Sendable {
        case top, middle, bottom

        var title: String {
            switch self {
            case .top: "Top"
            case .middle: "Middle"
            case .bottom: "Bottom"
            }
        }
    }

    /// The text's size as a share of the shorter side of the video on the canvas.
    var size = 0.045

    var position = Position.bottom

    var textColor = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)

    /// Whether the word being said takes ``highlightColor``.
    var highlightsWords = true

    var highlightColor = RGBAColor(red: 1, green: 0.8, blue: 0.2, alpha: 1)

    /// How opaque the dark box behind the text is, from 0 (no box) to 1.
    var backgroundOpacity = 0.6

    /// The range the inspector offers for ``size``.
    static let sizes = 0.02...0.08
}
