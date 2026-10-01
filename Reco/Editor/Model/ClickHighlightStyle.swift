//
//  ClickHighlightStyle.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// How clicks are highlighted: a ring that grows out of the click point and fades.
nonisolated struct ClickHighlightStyle: Codable, Equatable, Sendable {
    var isEnabled = true
    var color = RGBAColor(red: 1, green: 0.8, blue: 0, alpha: 1)

    /// The ring's diameter when fully grown, in screen points, so it has the same size next to the
    /// cursor on any display.
    var size = 44.0

    /// How long a ring shows, in seconds.
    var duration = 0.5

    var buttons = Buttons.all

    /// Which mouse buttons' clicks are highlighted.
    nonisolated enum Buttons: String, Codable, CaseIterable, Sendable {
        case all
        case left
        case right

        func includes(_ button: InputTelemetry.MouseButton) -> Bool {
            switch self {
            case .all: true
            case .left: button == .left
            case .right: button == .right
            }
        }
    }
}
