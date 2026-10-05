//
//  NotchGeometry.swift
//  Reco
//

import CoreGraphics

/// Where the notch shelf sits on one screen (spec 0013), in global screen coordinates (bottom-left origin):
/// the notch itself, or a small pill at the top centre of a screen without one; that shape grown a little
/// while the pointer is on it (the peek); and the opened panel. Every rect is flush with the top of the
/// screen.
nonisolated struct NotchGeometry: Equatable, Sendable {

    /// What stands in for the notch on a screen without one: small enough to be forgotten, wide enough
    /// to hit. The outline's radii are clamped to fit its height.
    static let pillSize = CGSize(width: 120, height: 8)

    /// The opened panel's width, and the height of its content below `contentTopInset`
    static let expandedWidth: CGFloat = 560
    static let bodyHeight: CGFloat = 132

    let hasNotch: Bool
    let collapsed: CGRect
    let expanded: CGRect

    /// - Parameters:
    ///   - screenFrame: `NSScreen.frame`
    ///   - leftArea: `NSScreen.auxiliaryTopLeftArea`, the menu bar left of the notch; nil or empty without one.
    ///     Only its width and height are read, so it doesn't matter whether it is in screen or global coordinates.
    ///   - rightArea: `NSScreen.auxiliaryTopRightArea`
    init(screenFrame: CGRect, leftArea: CGRect?, rightArea: CGRect?) {
        let left: CGRect = leftArea ?? .zero
        let right: CGRect = rightArea ?? .zero
        let notchWidth: CGFloat = screenFrame.width - left.width - right.width
        let notchHeight: CGFloat = max(left.height, right.height)
        let hasNotch = !left.isEmpty && !right.isEmpty && notchWidth > 0 && notchHeight > 0
        self.hasNotch = hasNotch

        let size: CGSize = hasNotch ? CGSize(width: notchWidth, height: notchHeight) : Self.pillSize
        let minX: CGFloat = hasNotch ? screenFrame.minX + left.width : screenFrame.midX - size.width / 2
        let collapsed = CGRect(x: minX, y: screenFrame.maxY - size.height, width: size.width, height: size.height)
        self.collapsed = collapsed

        let width: CGFloat = min(Self.expandedWidth, screenFrame.width)
        let height: CGFloat = min(Self.contentTopInset(hasNotch: hasNotch, collapsedHeight: size.height) + Self.bodyHeight, screenFrame.height)
        let originX: CGFloat = min(max(collapsed.midX - width / 2, screenFrame.minX), screenFrame.maxX - width)
        expanded = CGRect(x: originX, y: screenFrame.maxY - height, width: width, height: height)
    }

    /// The collapsed shape grown by `NotchMotion.peekGrowth`: while the pointer is on it
    var peek: CGRect {
        CGRect(
            x: collapsed.minX - NotchMotion.peekGrowth.width,
            y: collapsed.minY - NotchMotion.peekGrowth.height,
            width: collapsed.width + NotchMotion.peekGrowth.width * 2,
            height: collapsed.height + NotchMotion.peekGrowth.height
        )
    }

    /// Room to each side of the open panel and below it, in the window that never changes size: the open
    /// spring overshoots (about 2% of the width at damping 0.78, 11 pt on 560) and the shadow blurs 6 pt
    /// past the shape, so the shape never outgrows the window mid-animation. Clicks on the invisible rest
    /// of the window pass through (`NotchShelfController`).
    static let windowRoom: CGFloat = 24

    /// The window for the whole life of the shelf: flush with the top of the screen, centred on the open panel
    var window: CGRect {
        CGRect(
            x: expanded.minX - Self.windowRoom,
            y: expanded.minY - Self.windowRoom,
            width: expanded.width + Self.windowRoom * 2,
            height: expanded.height + Self.windowRoom
        )
    }

    /// The opened panel's content starts below the notch; below a pill, a little under the screen's top edge
    var contentTopInset: CGFloat {
        Self.contentTopInset(hasNotch: hasNotch, collapsedHeight: collapsed.height)
    }

    private static func contentTopInset(hasNotch: Bool, collapsedHeight: CGFloat) -> CGFloat {
        hasNotch ? collapsedHeight : 12
    }
}
