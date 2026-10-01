//
//  AreaSelectionPanel.swift
//  Reco
//
//  Created by Diip3sh on 30.09.26.
//

import AppKit

/// A borderless, transparent panel that covers a display for rectangle drawing
final class AreaSelectionPanel: NSPanel {

    /// Whether the panel takes the keyboard. One that doesn't leaves the app under it untouched,
    /// so its open menus and dropdowns stay open and can be captured.
    private let takesFocus: Bool

    init(screen: NSScreen, takesFocus: Bool) {
        self.takesFocus = takesFocus
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { takesFocus }
    override var canBecomeMain: Bool { takesFocus }
}
