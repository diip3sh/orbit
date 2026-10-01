//
//  StandardCursors.swift
//  Reco
//

import AppKit

/// The running macOS's standard `NSCursor`s, to recognise them among recorded cursor images.
///
/// The cursor another app shows is `NSCursor`'s own image down to the pixel, so an exact
/// ``CursorShapeTracker/Fingerprint`` match identifies it. Read from the running OS rather than
/// stored, so it stays right when Apple redraws its cursors.
enum StandardCursors {

    /// Every standard cursor's fingerprint with its kind. Built on first use.
    static let fingerprints: [(kind: CursorKind, fingerprint: CursorShapeTracker.Fingerprint)] =
        cursors.compactMap { kind, cursor in fingerprint(of: cursor).map { (kind, $0) } }

    /// A cursor's size, hotspot and smallest bitmap, or `nil` when its image has no bitmap.
    static func fingerprint(of cursor: NSCursor) -> CursorShapeTracker.Fingerprint? {
        let bitmaps = cursor.image.representations.compactMap { $0 as? NSBitmapImageRep }
        guard let smallest = bitmaps.min(by: { $0.pixelsWide < $1.pixelsWide }),
              let pixels = smallest.cgImage?.dataProvider?.data as Data?
        else { return nil }

        return .init(size: cursor.image.size, hotspot: cursor.hotSpot, pixels: pixels)
    }

    /// A cursor's largest bitmap as PNG, or no data when its image has no bitmap.
    static func png(of cursor: NSCursor) -> Data {
        let bitmaps = cursor.image.representations.compactMap { $0 as? NSBitmapImageRep }
        return bitmaps.max { $0.pixelsWide < $1.pixelsWide }?.representation(using: .png, properties: [:]) ?? Data()
    }

    /// The arrow, for an editor to draw when a recording has no cursor images.
    static var arrowSprite: InputTelemetry.CursorSprite {
        .init(id: 0, kind: .arrow, size: NSCursor.arrow.image.size, hotspot: NSCursor.arrow.hotSpot, png: png(of: .arrow))
    }

    /// A standard cursor as a sprite with `id`: the first of its kind, e.g. one direction of a resize.
    static func sprite(of kind: CursorKind, id: Int) -> InputTelemetry.CursorSprite? {
        guard let cursor = cursors.first(where: { $0.0 == kind })?.1 else { return nil }
        return .init(id: id, kind: kind, size: cursor.image.size, hotspot: cursor.hotSpot, png: png(of: cursor))
    }

    private static var cursors: [(CursorKind, NSCursor)] {
        let single: [(CursorKind, NSCursor)] = [
            (.arrow, .arrow),
            (.iBeam, .iBeam),
            (.iBeamVertical, .iBeamCursorForVerticalLayout),
            (.pointingHand, .pointingHand),
            (.openHand, .openHand),
            (.closedHand, .closedHand),
            (.crosshair, .crosshair),
            (.operationNotAllowed, .operationNotAllowed),
            (.dragCopy, .dragCopy),
            (.dragLink, .dragLink),
            (.contextualMenu, .contextualMenu),
            (.disappearingItem, .disappearingItem),
            (.zoomIn, .zoomIn),
            (.zoomOut, .zoomOut)
        ]

        let columns: [(CursorKind, NSCursor)] = [.left, .right, .all].map { (.columnResize, .columnResize(directions: $0)) }
        let rows: [(CursorKind, NSCursor)] = [.up, .down, .all].map { (.rowResize, .rowResize(directions: $0)) }

        let positions: [NSCursor.FrameResizePosition] = [.top, .left, .bottom, .right, .topLeft, .topRight, .bottomLeft, .bottomRight]
        let frames: [(CursorKind, NSCursor)] = positions.flatMap { position in
            [.inward, .outward, .all].map { (.frameResize, .frameResize(position: position, directions: $0)) }
        }

        return single + columns + rows + frames
    }
}
