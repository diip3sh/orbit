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

    /// A multiple of the cursor's size on screen.
    var size = 1.0

    var smoothing = Smoothing.smooth

    /// Whether the cursor shrinks while a mouse button is held.
    var animatesClicks = true

    /// Whether the cursor fades out when it hasn't moved or clicked for a while.
    var hidesWhenIdle = false

    /// Whether the cursor glides back to where it started as the video ends, so a loop is seamless.
    var loopsToStart = false

    /// For how many seconds before the end the cursor stays where it is, which hides the reach for Stop.
    var stopsBeforeEnd = 0.0

    /// Whether the cursor leans the way it moves.
    var tilts = false

    /// How much the cursor's moves are blurred, from 0 for none to 1.
    var motionBlur = 0.5

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

    /// Settings added after the first projects were saved take their defaults when missing.
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        size = try container.decode(Double.self, forKey: .size)
        smoothing = try container.decode(Smoothing.self, forKey: .smoothing)
        animatesClicks = try container.decode(Bool.self, forKey: .animatesClicks)
        hidesWhenIdle = try container.decode(Bool.self, forKey: .hidesWhenIdle)
        loopsToStart = try container.decodeIfPresent(Bool.self, forKey: .loopsToStart) ?? false
        stopsBeforeEnd = try container.decodeIfPresent(Double.self, forKey: .stopsBeforeEnd) ?? 0
        tilts = try container.decodeIfPresent(Bool.self, forKey: .tilts) ?? false
        motionBlur = try container.decodeIfPresent(Double.self, forKey: .motionBlur) ?? 0.5
    }
}
