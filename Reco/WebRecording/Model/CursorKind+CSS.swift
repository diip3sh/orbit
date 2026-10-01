//
//  CursorKind+CSS.swift
//  Reco
//

import Foundation

nonisolated extension CursorKind {

    /// The standard cursor a CSS `cursor` value shows on macOS, or `nil` for the arrow and for
    /// values without their own standard cursor, like resize cursors, which come in several shapes.
    init?(css value: String) {
        guard let kind = Self.cssCursors[value] else { return nil }
        self = kind
    }

    private static let cssCursors: [String: CursorKind] = [
        "pointer": .pointingHand,
        "text": .iBeam,
        "vertical-text": .iBeamVertical,
        "grab": .openHand,
        "grabbing": .closedHand,
        "crosshair": .crosshair,
        "not-allowed": .operationNotAllowed,
        "no-drop": .operationNotAllowed,
        "copy": .dragCopy,
        "alias": .dragLink,
        "context-menu": .contextualMenu,
        "zoom-in": .zoomIn,
        "zoom-out": .zoomOut
    ]
}
