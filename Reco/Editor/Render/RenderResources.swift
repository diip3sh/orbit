//
//  RenderResources.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics

/// What render plans draw with that the editor reads from the system, outside the project.
nonisolated struct RenderResources: Sendable {

    /// Labels keystrokes; without it, none are shown.
    var keyLabels: KeyLabelFormatter?

    /// The cursor drawn when the telemetry has no cursor images.
    var arrow: InputTelemetry.CursorSprite?

    /// The picture of the canvas's image background.
    var background: CGImage?

    static let none = RenderResources()
}
