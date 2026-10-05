//
//  CaptureToolbarPlacement.swift
//  Reco
//

import CoreGraphics

/// Where the capture toolbar sits: its home, bottom-centre of the screen's visible frame above the Dock,
/// where a drag shows it, and where a release leaves it. Screen coordinates, bottom-left origin.
nonisolated enum CaptureToolbarPlacement {

    /// Space between the bar and the bottom of the visible frame (the Dock's top, or the screen's edge)
    static let bottomMargin: CGFloat = 48

    /// Kept clear of the visible frame's edges after a drag
    static let edgeMargin: CGFloat = 8

    /// A release whose projected centre lands this close to home goes home
    static let homeSnapDistance: CGFloat = 64

    /// Between the bar and the tooltip window above it. The tooltip view adds its own 6 pt margin inside
    /// its window, so the tail's tip ends up 6 pt clear of the bar's glass. Measured from the bar's window
    /// it was 20 pt, since that reaches the bar's 12 pt margin past it.
    static let tooltipGap: CGFloat = 0

    /// The bar's own origin inside its window: the bar sits centred at the window's bottom, `margin` in
    /// from its edges. The window can be wider than the bar and taller, since the picker for a window or
    /// a display is drawn above the bar in the same one.
    static func barOrigin(inWindow frame: CGRect, barSize: CGSize, margin: CGFloat) -> CGPoint {
        CGPoint(x: frame.midX - barSize.width / 2, y: frame.minY + margin)
    }

    /// Where the window goes for a bar at `barOrigin`, sized `windowSize`
    static func windowOrigin(for barOrigin: CGPoint, windowSize: CGSize, barSize: CGSize, margin: CGFloat) -> CGPoint {
        CGPoint(
            x: barOrigin.x - (windowSize.width - barSize.width) / 2,
            y: barOrigin.y - margin
        )
    }

    /// The bar's origin at home: centred, `bottomMargin` above the bottom of `visibleFrame`
    static func home(size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        CGPoint(x: (visibleFrame.midX - size.width / 2).rounded(), y: visibleFrame.minY + bottomMargin)
    }

    /// The origins the bar can rest at in `visibleFrame`
    static func range(size: CGSize, in visibleFrame: CGRect) -> (x: ClosedRange<Double>, y: ClosedRange<Double>) {
        let bounds = visibleFrame.insetBy(dx: edgeMargin, dy: edgeMargin)
        return (
            bounds.minX...max(bounds.minX, bounds.maxX - size.width),
            bounds.minY...max(bounds.minY, bounds.maxY - size.height)
        )
    }

    /// Where a drag shows the bar for a pointer-led `origin`: 1:1 inside the visible frame, resisting past it
    static func dragged(_ origin: CGPoint, size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        let range = range(size: size, in: visibleFrame)
        return CGPoint(
            x: GesturePhysics.rubberbanded(origin.x, in: range.x, dimension: size.width),
            y: GesturePhysics.rubberbanded(origin.y, in: range.y, dimension: size.height)
        )
    }

    /// Where a release at `origin` moving at `velocity` (points per second) comes to rest: carried by its
    /// momentum, kept inside the visible frame, and home when it ends near there.
    static func resting(_ origin: CGPoint, velocity: CGVector, size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        let range = range(size: size, in: visibleFrame)
        let projected = CGPoint(
            x: origin.x + GesturePhysics.project(velocity: velocity.dx),
            y: origin.y + GesturePhysics.project(velocity: velocity.dy)
        )
        let home = home(size: size, in: visibleFrame)
        if hypot(projected.x - home.x, projected.y - home.y) <= homeSnapDistance {
            return home
        }
        return CGPoint(
            x: min(max(projected.x, range.x.lowerBound), range.x.upperBound),
            y: min(max(projected.y, range.y.lowerBound), range.y.upperBound)
        )
    }

    /// Where a window above the bar sits (a tooltip, the picker): centred on `midX`, `gap` above the bar's
    /// window, or below when there is no room above, and inside the screen either way. Screen coordinates.
    static func rectAbove(barFrame: CGRect, size: CGSize, midX: CGFloat, gap: CGFloat = tooltipGap, in visibleFrame: CGRect) -> CGRect {
        let bounds = visibleFrame.insetBy(dx: edgeMargin, dy: edgeMargin)
        let originX = min(max(midX - size.width / 2, bounds.minX), max(bounds.minX, bounds.maxX - size.width))
        let above = barFrame.maxY + gap
        let originY = above + size.height <= bounds.maxY
            ? above
            : max(barFrame.minY - gap - size.height, bounds.minY)
        return CGRect(x: originX.rounded(), y: originY.rounded(), width: size.width, height: size.height)
    }
}
