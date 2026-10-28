//
//  HeaderMenuSwitcher.swift
//  Reco
//

import AppKit
import SwiftUI

/// Lets one click go from an open header menu to another header menu of the same window, as the menu bar
/// lets the pointer go from menu to menu. A click outside an open menu only closes it: AppKit's menu tracking
/// keeps the press, so the menu under it took a second click.
///
/// The header's menus are SwiftUI views, which hit-testing can't tell apart, so each marks its label with
/// `headerMenuAnchor()`: the anchor's backing view says where its menu is.
final class HeaderMenuSwitcher: NSObject {
    private weak var window: NSWindow?

    /// The anchor whose menu is open, from the press that opened it.
    private weak var opener: HeaderMenuAnchorView?

    init(window: NSWindow) {
        self.window = window
        super.init()
        // Selector observers are removed when the observer is released
        NotificationCenter.default.addObserver(self, selector: #selector(menuDidBeginTracking), name: NSMenu.didBeginTrackingNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(menuDidEndTracking), name: NSMenu.didEndTrackingNotification, object: nil)
    }

    @objc private func menuDidBeginTracking(_ notification: Notification) {
        // The press that opened the menu is gone by now (the note is posted after it), but the
        // pointer is still on the menu that was asked for
        guard let window else {
            opener = nil
            return
        }
        opener = anchor(at: window.convertPoint(fromScreen: NSEvent.mouseLocation))
        Self.debug("begin: opener=\(opener != nil) anchors=\(window.contentView.map { anchors(in: $0).count } ?? -1)")
    }

    @objc private func menuDidEndTracking(_ notification: Notification) {
        defer { opener = nil }
        // The note is posted after the whole click, so pressedMouseButtons and currentEvent can't say
        // how tracking ended. The pointer can: it rests on the menu the click was meant for. A click on
        // the opener or elsewhere, picking an item (the pointer is over the menu, below the capsules)
        // and Esc (a key event is current) only close the menu
        guard let opener, let window, NSApp.currentEvent?.type != .keyDown else { return }
        let location = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        Self.debug("end: location=\(location) target=\(anchor(at: location) != nil) currentEvent=\(String(describing: NSApp.currentEvent?.type))")
        guard let target = anchor(at: location), target !== opener,
              let press = NSEvent.mouseEvent(
                  with: .leftMouseDown, location: location, modifierFlags: NSEvent.modifierFlags,
                  timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                  context: nil, eventNumber: 0, clickCount: 1, pressure: 1
              ),
              let release = NSEvent.mouseEvent(
                  with: .leftMouseUp, location: location, modifierFlags: NSEvent.modifierFlags,
                  timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                  context: nil, eventNumber: 0, clickCount: 1, pressure: 0
              ) else { return }
        // A full click: the press the menu tracking kept, then the release that leaves the menu open
        Self.debug("end: reposting click")
        NSApp.postEvent(press, atStart: true)
        NSApp.postEvent(release, atStart: false)
    }

    static func debug(_ message: String) {
        let line = "\(Date()): \(message)\n"
        let url = URL(filePath: "/tmp/switcher-debug.log")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    /// The header menu's anchor under `point`, in window coordinates.
    private func anchor(at point: NSPoint) -> HeaderMenuAnchorView? {
        guard let window, let contentView = window.contentView else { return nil }
        return anchors(in: contentView).first { anchor in
            anchor.window === window && anchor.convert(anchor.bounds, to: nil).contains(point)
        }
    }

    private func anchors(in view: NSView) -> [HeaderMenuAnchorView] {
        view.subviews.flatMap { subview in
            (subview as? HeaderMenuAnchorView).map { [$0] } ?? anchors(in: subview)
        }
    }
}

/// The backing view of `headerMenuAnchor()`: an empty view laid out with its menu's label, which
/// `HeaderMenuSwitcher` finds in the window's view tree.
final class HeaderMenuAnchorView: NSView {
    override var acceptsFirstResponder: Bool { false }
}

private struct HeaderMenuAnchor: NSViewRepresentable {
    func makeNSView(context: Context) -> HeaderMenuAnchorView {
        HeaderMenuAnchorView()
    }

    func updateNSView(_ nsView: HeaderMenuAnchorView, context: Context) {}
}

extension View {

    /// Marks a header menu's label, so `HeaderMenuSwitcher` can send it the press that closed another menu.
    func headerMenuAnchor() -> some View {
        background(HeaderMenuAnchor())
    }
}
