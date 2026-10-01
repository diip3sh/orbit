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
        // Appears at once: the default zoom-in would shrink and grow the frozen screen it shows
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { takesFocus }
    override var canBecomeMain: Bool { takesFocus }

    /// Shows the selection over `background`, the screen as it was when the selection started, or over the live screen
    func show(_ selection: AreaSelectionView, over background: CGImage?) {
        guard let background else {
            contentView = selection
            return
        }
        let frozen = NSImageView(frame: selection.frame)
        frozen.image = NSImage(cgImage: background, size: selection.frame.size)
        frozen.imageScaling = .scaleAxesIndependently
        // Own layers, so the hole the selection clears in its dimming shows the frozen screen
        frozen.wantsLayer = true
        selection.wantsLayer = true

        let container = NSView(frame: selection.frame)
        container.addSubview(frozen)
        container.addSubview(selection)
        contentView = container
    }
}
