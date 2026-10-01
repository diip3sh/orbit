//
//  PanelDragger.swift
//  Reco
//

import AppKit

/// Moves a panel with the pointer, 1:1, from wherever it was grabbed, and on release throws it
/// off screen if the drag ended in a flick (`GesturePhysics.flickExit`). A slow drag, or a flick
/// inwards, leaves it where it was dropped.
///
/// Works in screen coordinates (`NSEvent.mouseLocation`): the panel moves under the pointer, so
/// the gesture's own coordinates shift with it.
@MainActor
final class PanelDragger {

    weak var panel: NSPanel?

    /// Called once a flick has carried the panel away, to close it.
    var onFlick: (@MainActor () -> Void)?

    private var tracker = VelocityTracker()
    private var grabOffset: CGSize?

    /// A drag callback: starts the drag on the first call, then follows the pointer.
    func drag() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let offset = grabOffset ?? CGSize(width: mouse.x - panel.frame.minX, height: mouse.y - panel.frame.minY)
        grabOffset = offset
        tracker.add(mouse, at: ProcessInfo.processInfo.systemUptime)
        panel.setFrameOrigin(CGPoint(x: mouse.x - offset.width, y: mouse.y - offset.height))
    }

    /// The drag's end: carries the panel off the way it was thrown, or leaves it.
    func end() {
        defer {
            grabOffset = nil
            tracker = VelocityTracker()
        }
        guard grabOffset != nil, let panel else { return }

        let velocity = tracker.velocity
        let bounds = (panel.screen ?? NSScreen.main)?.frame ?? panel.frame
        guard let target = GesturePhysics.flickExit(frame: panel.frame, velocity: velocity, bounds: bounds) else { return }

        panel.ignoresMouseEvents = true
        let reducesMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let distance = hypot(target.minX - panel.frame.minX, target.minY - panel.frame.minY)
        NSAnimationContext.runAnimationGroup { context in
            if reducesMotion {
                context.duration = 0.15
            } else {
                // Leaves at the release speed: this curve starts at slope 3
                context.duration = GesturePhysics.velocityMatchedDuration(distance: distance, velocity: hypot(velocity.dx, velocity.dy))
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.75, 0.5, 1)
                panel.animator().setFrame(target, display: true)
            }
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { self.onFlick?() }
        }
    }
}
