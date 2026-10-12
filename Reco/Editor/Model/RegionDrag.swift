//
//  RegionDrag.swift
//  Reco
//

import CoreGraphics

/// Dragging a rectangle on a picture of the video, for the crop and masks: rectangles are fractions of the video
/// from its top-left corner.
nonisolated enum RegionDrag {

    /// The sides of the rectangle a drag moves; all four move it whole.
    struct Edges: OptionSet, Sendable {
        let rawValue: Int
        static let left = Edges(rawValue: 1 << 0)
        static let top = Edges(rawValue: 1 << 1)
        static let right = Edges(rawValue: 1 << 2)
        static let bottom = Edges(rawValue: 1 << 3)
        static let all: Edges = [.left, .top, .right, .bottom]
    }

    /// `region` at least `minimumSize` on each side and inside the video
    static func clamped(_ region: CGRect, minimumSize: Double) -> CGRect {
        let width = min(max(region.width, minimumSize), 1)
        let height = min(max(region.height, minimumSize), 1)
        return CGRect(x: min(max(region.minX, 0), 1 - width), y: min(max(region.minY, 0), 1 - height), width: width, height: height)
    }

    /// `region` with `edges` moved by `delta`: all four move it inside the video, keeping its size; otherwise each
    /// edge stops at the video's edge and `minimumSize` from the opposite one.
    static func dragged(_ region: CGRect, edges: Edges, by delta: CGSize, minimumSize: Double) -> CGRect {
        guard edges != .all else { return clamped(region.offsetBy(dx: delta.width, dy: delta.height), minimumSize: minimumSize) }
        var (minX, minY, maxX, maxY) = (region.minX, region.minY, region.maxX, region.maxY)
        if edges.contains(.left) { minX = min(max(region.minX + delta.width, 0), region.maxX - minimumSize) }
        if edges.contains(.right) { maxX = max(min(region.maxX + delta.width, 1), region.minX + minimumSize) }
        if edges.contains(.top) { minY = min(max(region.minY + delta.height, 0), region.maxY - minimumSize) }
        if edges.contains(.bottom) { maxY = max(min(region.maxY + delta.height, 1), region.minY + minimumSize) }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
