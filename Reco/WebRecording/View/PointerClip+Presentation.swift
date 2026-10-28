//
//  PointerClip+Presentation.swift
//  Reco
//

import Foundation

/// How a cursor clip's action reads in the window: its name and symbol.
extension PointerClip.Action {

    var title: String {
        switch self {
        case .hover: "Hover"
        case .click: "Click"
        case .type: "Type"
        }
    }

    var symbol: String {
        switch self {
        case .hover: "cursorarrow"
        case .click: "cursorarrow.click"
        case .type: "character.cursor.ibeam"
        }
    }

    /// The stage's key that adds a clip of this action.
    var key: Character {
        switch self {
        case .hover: "h"
        case .click: "c"
        case .type: "t"
        }
    }
}

extension ScrollClip {

    static let symbol = "chevron.up.chevron.down"

    static let key: Character = "s"
}

extension CGSize {

    /// "1440×900": whole pixels without grouping, which a `Text` interpolating the numbers would add.
    var pixels: String {
        "\(Int(width))×\(Int(height))"
    }
}

extension WebTarget {

    /// The element as the last step of its selector, e.g. `button.buy`, or its point.
    var name: String {
        if let selector, let last = selector.split(separator: " > ").last {
            return String(last)
        }
        return "\(Int(point.x)), \(Int(point.y))"
    }
}
