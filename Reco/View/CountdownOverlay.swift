//
//  CountdownOverlay.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import AppKit
import KeyboardShortcuts
import SwiftUI

/// Shows the countdown number over what is about to be recorded, and cancels it on Esc.
///
/// The panel is click-through and non-activating, so the app being recorded keeps focus. Esc is a
/// temporary global hotkey (Carbon, via KeyboardShortcuts), registered only while the panel shows:
/// key event monitors never fire in the sandbox.
@MainActor
final class CountdownOverlay {

    private var panel: NSPanel?
    private var escapeTask: Task<Void, Never>?

    /// - Parameter center: Point to centre on, in screen coordinates (bottom-left origin). `nil` uses the main screen.
    func show(countdown: RecordingCountdown, center: CGPoint?, onEscape: @escaping @MainActor () -> Void) {
        dismiss()

        let size: CGFloat = 200
        let center = center ?? NSScreen.main.map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) } ?? .zero
        let panel = NSPanel(
            contentRect: CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.contentView = NSHostingView(rootView: CountdownView(countdown: countdown))
        panel.orderFront(nil)
        self.panel = panel

        escapeTask = Task {
            for await _ in KeyboardShortcuts.events(.keyDown, for: KeyboardShortcuts.Shortcut(.escape)) {
                onEscape()
                break
            }
        }
    }

    /// Removes the panel and releases Esc. At once, with no exit animation: a recording starts
    /// right after, and the disc must not land in its first frame.
    func dismiss() {
        escapeTask?.cancel()
        escapeTask = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }
}
