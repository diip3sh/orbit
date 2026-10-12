//
//  ToolbarMenuSwitcher.swift
//  Reco
//

import AppKit

/// Lets one click go from an open toolbar menu to another toolbar item of the same window, as the menu bar
/// lets the pointer go from menu to menu. A click outside an open menu only closes it: AppKit's menu tracking
/// keeps the press, so the item under it took a second click.
final class ToolbarMenuSwitcher: NSObject {
    private weak var window: NSWindow?

    /// The toolbar item whose menu is open, from the press that opened it.
    private weak var opener: NSView?

    init(window: NSWindow) {
        self.window = window
        super.init()
        // Selector observers are removed when the observer is released
        NotificationCenter.default.addObserver(self, selector: #selector(menuDidBeginTracking), name: NSMenu.didBeginTrackingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuDidEndTracking), name: NSMenu.didEndTrackingNotification, object: nil)
    }

    @objc private func menuDidBeginTracking(_ notification: Notification) {
        // The press that opened the menu, still current when tracking begins
        guard let event = NSApp.currentEvent, event.type == .leftMouseDown, event.window === window else {
            opener = nil
            return
        }
        opener = toolbarItemView(at: event.locationInWindow)
    }

    @objc private func menuDidEndTracking(_ notification: Notification) {
        defer { opener = nil }
        // Closed by a press elsewhere: the button is still down, or the press is the current event. Picking an
        // item ends on the release, and Esc or a press on the opener itself only closes the menu
        let closedByPress = NSEvent.pressedMouseButtons & 1 != 0 || NSApp.currentEvent?.type == .leftMouseDown
        guard let opener, let window, closedByPress else { return }
        let location = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        guard let target = toolbarItemView(at: location), target !== opener,
              let press = NSEvent.mouseEvent(
                  with: .leftMouseDown, location: location, modifierFlags: NSEvent.modifierFlags,
                  timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                  context: nil, eventNumber: 0, clickCount: 1, pressure: 1
              ) else { return }
        // The real release follows it from the queue, so the next menu opens and stays as a click leaves it
        NSApp.postEvent(press, atStart: true)
    }

    /// The view of the window's toolbar item under `point`, in window coordinates.
    private func toolbarItemView(at point: NSPoint) -> NSView? {
        guard let window, let frame = window.contentView?.superview,
              let hit = frame.hitTest(frame.convert(point, from: nil)) else { return nil }
        return window.toolbar?.items.lazy.compactMap(\.view).first { hit.isDescendant(of: $0) }
    }
}
