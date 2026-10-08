//
//  Font+Theme.swift
//  Reco
//

import AppKit
import SwiftUI

extension Font {

    /// `style` in Reco's typeface. Sizes are macOS's own for each style, so layouts measured against the system
    /// font keep their room, except the two largest, which take the token scale's 20 and 24; `weight` defaults to
    /// the style's (590 for headline and the titles, 400 otherwise). macOS has no Dynamic Type, so a fixed size per
    /// style is what the system font does too.
    static func theme(_ style: TextStyle = .body, weight: Weight? = nil, _ typeface: Typeface = .sans) -> Font {
        Font(NSFont.theme(style, weight: weight, typeface) as CTFont)
    }
}

extension NSFont {

    /// `Font.theme` for AppKit text.
    static func theme(_ style: Font.TextStyle = .body, weight: Font.Weight? = nil, _ typeface: Typeface = .sans) -> NSFont {
        typeface.font(size: style.pointSize, weight: (weight ?? style.defaultWeight).axisValue)
    }
}

extension Font.TextStyle {

    var pointSize: CGFloat {
        switch self {
        case .largeTitle: 24
        case .title: 20
        case .title2: 17
        case .title3: 15
        case .headline, .body: 13
        case .callout: 12
        case .subheadline: 11
        case .footnote, .caption, .caption2: 10
        @unknown default: 13
        }
    }

    var defaultWeight: Font.Weight {
        switch self {
        case .headline, .title, .title2: .semibold
        default: .regular
        }
    }
}

extension Font.Weight {

    /// The `wght` axis' value. Medium and semibold are Linear's 510 and 590, between Inter's named instances.
    var axisValue: CGFloat {
        switch self {
        case .ultraLight: 200
        case .thin: 100
        case .light: 300
        case .medium: 510
        case .semibold: 590
        case .bold: 700
        case .heavy: 800
        case .black: 900
        default: 400
        }
    }
}
