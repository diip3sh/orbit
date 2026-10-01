//
//  DisplayGeometry.swift
//  Reco
//
//  Created by Joshua Sattler on 29.08.26.
//

import CoreGraphics
import Foundation

/// A display's position and backing scale, expressed in the global CoreGraphics coordinate
/// space that `SCWindow.frame` and `CGDisplayBounds` use: points, top-left origin, Y increasing
/// downwards. Displays arranged above the primary one therefore have a negative Y origin.
struct DisplayGeometry: Equatable, Sendable {

    /// The display's bounds in global CoreGraphics points.
    let frame: CGRect

    /// The number of pixels per point on this display.
    let scaleFactor: CGFloat
}
