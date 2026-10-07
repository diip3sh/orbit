//
//  CursorStyle.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import Foundation

/// How the editor draws the cursor of a recording made without it.
nonisolated struct CursorStyle: Codable, Equatable, Sendable {
    var isEnabled = true

    var appearance = Appearance.recorded

    /// Draws the recording's arrow where it showed another shape (I-beam, hand, resize), so the cursor is
    /// one shape throughout. Only for ``Appearance/recorded``.
    var alwaysUsesArrow = false

    /// Glides the cursor back to where it started over the last second, so the video loops.
    var loops = false

    /// A multiple of the cursor's size on screen.
    var size = 1.0

    var smoothing = Smoothing.smooth

    /// Whether the cursor shrinks while a mouse button is held.
    var animatesClicks = true

    /// Whether the cursor fades out when it hasn't moved or clicked for a while.
    var hidesWhenIdle = false

    /// What the cursor looks like.
    nonisolated enum Appearance: String, Codable, CaseIterable, Sendable {
        /// The system cursors that were recorded.
        case recorded
        case white
        case dot
    }

    /// How closely the drawn cursor follows the recorded one.
    nonisolated enum Smoothing: String, Codable, CaseIterable, Sendable {
        case mellow
        case smooth
        case fast

        /// The smoothing spring's natural frequency, in radians per second. The cursor trails a
        /// steady move by 2 / `frequency` seconds: 290 ms, 160 ms and 80 ms. Smooth is the default
        /// spring of Cap (tension 470, mass 3) made critically damped; Cap's friction of 70
        /// overshoots by 0.03%, which doesn't show.
        var frequency: Double {
            switch self {
            case .mellow: 7
            case .smooth: 12.5
            case .fast: 25
            }
        }
    }
}

// MARK: - Decoding

extension CursorStyle {

    /// Settings added after a project was saved take their defaults when missing.
    nonisolated init(from decoder: any Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? isEnabled
        appearance = try container.decodeIfPresent(Appearance.self, forKey: .appearance) ?? appearance
        alwaysUsesArrow = try container.decodeIfPresent(Bool.self, forKey: .alwaysUsesArrow) ?? alwaysUsesArrow
        loops = try container.decodeIfPresent(Bool.self, forKey: .loops) ?? loops
        size = try container.decodeIfPresent(Double.self, forKey: .size) ?? size
        smoothing = try container.decodeIfPresent(Smoothing.self, forKey: .smoothing) ?? smoothing
        animatesClicks = try container.decodeIfPresent(Bool.self, forKey: .animatesClicks) ?? animatesClicks
        hidesWhenIdle = try container.decodeIfPresent(Bool.self, forKey: .hidesWhenIdle) ?? hidesWhenIdle
    }
}
