//
//  ResizeHandle.swift
//  Reco
//

import AppKit

/// One of the eight handles on an area selection's edges and corners
enum ResizeHandle {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight

    /// The native macOS frame resize cursor for the handle's position
    var cursor: NSCursor {
        let directions: NSCursor.FrameResizeDirection.Set = [.inward, .outward]

        switch self {
        case .topLeft: return .frameResize(position: .topLeft, directions: directions)
        case .top: return .frameResize(position: .top, directions: directions)
        case .topRight: return .frameResize(position: .topRight, directions: directions)
        case .left: return .frameResize(position: .left, directions: directions)
        case .right: return .frameResize(position: .right, directions: directions)
        case .bottomLeft: return .frameResize(position: .bottomLeft, directions: directions)
        case .bottom: return .frameResize(position: .bottom, directions: directions)
        case .bottomRight: return .frameResize(position: .bottomRight, directions: directions)
        }
    }
}
