//
//  ColorPanelPlacement.swift
//  Reco
//

import AppKit

/// Opens the system Colors panel beside the window whose color well opened it, instead of wherever
/// it was last (a corner of the screen, far from the inspector).
@MainActor
enum ColorPanelPlacement {

    private static var observers: [any NSObjectProtocol] = []

    /// Whether the panel was placed since it opened, so a panel the user moved stays where they put it.
    private static var isPlaced = false

    /// Places the panel each time it opens. Call once at launch.
    static func start() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { notification in
                // Only the panel's own notifications; nothing else crosses over
                guard notification.object is NSColorPanel else { return }
                MainActor.assumeIsolated { placeOnce() }
            },
            center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { notification in
                guard notification.object is NSColorPanel else { return }
                MainActor.assumeIsolated { isPlaced = false }
            }
        ]
    }

    private static func placeOnce() {
        let panel = NSColorPanel.shared
        guard !isPlaced,
              let window = NSApp.orderedWindows.first(where: { $0 !== panel && $0.isVisible && $0.canBecomeMain }),
              let screen = window.screen?.visibleFrame
        else { return }
        isPlaced = true
        panel.setFrameOrigin(origin(of: panel.frame.size, beside: window.frame, in: screen))
    }

    /// Right of `window` when it fits on the screen, else just inside its right edge, over the
    /// stage left of the inspector; top-aligned below the title bar, kept on screen.
    static func origin(of size: CGSize, beside window: CGRect, in screen: CGRect, gap: CGFloat = 8, inset: CGFloat = 340) -> CGPoint {
        let outside = window.maxX + gap
        let x = outside + size.width <= screen.maxX ? outside : window.maxX - inset - size.width - gap
        let top = window.maxY - 52
        return CGPoint(
            x: min(max(x, screen.minX), screen.maxX - size.width),
            y: min(max(top - size.height, screen.minY), screen.maxY - size.height)
        )
    }
}
