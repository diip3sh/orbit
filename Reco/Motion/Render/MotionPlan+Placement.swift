//
//  MotionPlan+Placement.swift
//  Reco
//

import CoreGraphics

extension MotionPlan {

    /// A layer where it lands on the canvas at one moment.
    nonisolated struct Placement: Equatable, Sendable {
        let layer: Int

        /// Top-left, top-right, bottom-right and bottom-left, in canvas pixels from the top-left.
        var corners: [CGPoint]

        /// The centre's distance from the camera looking straight, not turned (``CameraProjection/order(of:)``); drawn farthest first.
        let depth: Double

        let opacity: Double

        /// In canvas pixels, scaled as the layer is.
        let blur: Double

        /// How many canvas pixels a layer pixel covers at its widest edge.
        let scale: Double

        /// The corners of the shadow's image, like ``corners``; `nil` without a shadow.
        var shadowCorners: [CGPoint]?

        /// The corners of the room its letters spring through (``Layer/revealRoom``), like ``corners``; `nil` without it.
        var roomCorners: [CGPoint]?

        /// The camera's blur at each corner in canvas pixels, signed: negative in front of what's
        /// in focus. Empty without depth of field.
        var defocus: [Double] = []
    }
}
