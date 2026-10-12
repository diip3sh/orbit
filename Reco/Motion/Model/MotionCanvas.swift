//
//  MotionCanvas.swift
//  Reco
//

import CoreGraphics

/// The frame every scene is drawn in.
nonisolated struct MotionCanvas: Equatable, Sendable {
    var size = CGSize(width: 1920, height: 1080)

    /// Whole frames per second.
    var frameRate = 60

    /// Near-black, as the dark reference videos (mean luma 12.7–23.7); never pure black.
    var background = RGBAColor(red: 0.031, green: 0.035, blue: 0.039, alpha: 1)

    /// What every scene is drawn over unless it names its own.
    var field = MotionField.plain

    /// How strongly the field shows over the background, 0 to 1: motion design's small UI wants its light toned
    /// down to a glow (spec 0014).
    var fieldStrength = 1.0

    var pacing = Pacing.driftAndCut

    /// The two ways the reference films move (spec 0011, *Measured references*).
    nonisolated enum Pacing: String, Codable, Sendable {
        /// Linear: 3–5 s shots, the camera drifting at constant speed, hard cuts hiding every start
        /// and stop; eased motion only inside the UI.
        case driftAndCut
        /// Raycast, Framer, Notion: 1–2 s beats, eased camera moves, long settles.
        case beats
    }
}

// MARK: - Codable

nonisolated extension MotionCanvas: Codable {

    init(from decoder: any Decoder) throws {
        let defaults = MotionCanvas()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        size = try container.decodeIfPresent(CGSize.self, forKey: .size) ?? defaults.size
        frameRate = try container.decodeIfPresent(Int.self, forKey: .frameRate) ?? defaults.frameRate
        background = try container.decodeIfPresent(RGBAColor.self, forKey: .background) ?? defaults.background
        field = try container.decodeIfPresent(MotionField.self, forKey: .field) ?? defaults.field
        fieldStrength = try container.decodeIfPresent(Double.self, forKey: .fieldStrength) ?? defaults.fieldStrength
        pacing = try container.decodeIfPresent(Pacing.self, forKey: .pacing) ?? defaults.pacing
    }
}
