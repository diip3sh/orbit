//
//  ClickHighlightStyle.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// How clicks are highlighted: a ring or two that grow out of the click point and fade.
nonisolated struct ClickHighlightStyle: Codable, Equatable, Sendable {
    var effect = Effect.circle
    var color = RGBAColor(red: 1, green: 0.8, blue: 0, alpha: 1)

    /// The ring's diameter when fully grown, in screen points, so it has the same size next to the
    /// cursor on any display.
    var size = 44.0

    /// How long a ring shows, in seconds.
    var duration = 0.5

    var buttons = Buttons.all

    nonisolated enum Effect: String, Codable, CaseIterable, Sendable {
        case off

        /// One ring over a faint fill.
        case circle

        /// Two empty rings, the second following the first.
        case ripple

        var ringCount: Int {
            switch self {
            case .off: 0
            case .circle: 1
            case .ripple: 2
            }
        }

        /// A ring's size, as a share of the full diameter, when it starts.
        var startScale: Double {
            self == .ripple ? 0.2 : 0.4
        }

        /// How far ring `index` has come at `age`, a share of the click's duration, from 0 to 1, or
        /// `nil` while it isn't showing. A ripple's rings each last 70% of the duration and the second
        /// starts 30% after the first, so both are done when the duration is.
        func progress(ofRing index: Int, atAge age: Double) -> Double? {
            let progress = self == .ripple ? (age - 0.3 * Double(index)) / 0.7 : age
            return (0...1).contains(progress) ? progress : nil
        }
    }

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

// MARK: - Decoding

extension ClickHighlightStyle {

    /// Projects saved before ``Effect`` had a switch, `isEnabled`, which turned the ring on or off.
    private enum LegacyKeys: String, CodingKey {
        case isEnabled
    }

    /// Settings added after a project was saved take their defaults when missing.
    nonisolated init(from decoder: any Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let effect = try container.decodeIfPresent(Effect.self, forKey: .effect) {
            self.effect = effect
        } else if try decoder.container(keyedBy: LegacyKeys.self).decodeIfPresent(Bool.self, forKey: .isEnabled) == false {
            effect = .off
        }
        color = try container.decodeIfPresent(RGBAColor.self, forKey: .color) ?? color
        size = try container.decodeIfPresent(Double.self, forKey: .size) ?? size
        duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? duration
        buttons = try container.decodeIfPresent(Buttons.self, forKey: .buttons) ?? buttons
    }
}
