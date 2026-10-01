//
//  CursorKind.swift
//  Reco
//

import Foundation

/// A standard macOS cursor, as `NSCursor` provides it.
///
/// Says what a recorded cursor image shows, so an editor can treat shapes by meaning, e.g. restyle
/// arrows or read an I-beam as typing. Resize cursors share one kind per family; the image shows
/// their position and direction.
nonisolated enum CursorKind: String, Codable, Sendable {
    case arrow
    case iBeam
    case iBeamVertical
    case pointingHand
    case openHand
    case closedHand
    case crosshair
    case operationNotAllowed
    case dragCopy
    case dragLink
    case contextualMenu
    case disappearingItem
    case zoomIn
    case zoomOut
    case columnResize
    case rowResize
    case frameResize
}
