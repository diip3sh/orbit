//
//  CapturableWindow.swift
//  Reco
//
//  Created by Joshua Sattler on 30.08.26.
//

import CoreGraphics
import Foundation

/// A window on screen, reduced to the properties the content filter rules need.
///
/// `SCWindow` cannot be constructed outside a `SCShareableContent` query, which requires
/// screen recording permission, so the classification rules operate on this value type
/// instead and stay unit testable.
struct CapturableWindow: Equatable, Sendable {

    /// The window's identifier, used to map back to the matching `SCWindow`.
    let id: CGWindowID

    /// The bundle identifier of the application owning the window, or an empty string.
    let bundleID: String

    /// The window's title, or an empty string.
    let title: String
}
