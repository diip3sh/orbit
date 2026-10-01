//
//  PinController.swift
//  Reco
//
//  Created by Diip3sh on 29.09.26.
//

import AppKit
import SwiftUI

/// Screenshots pinned on screen (roadmap C8): each in its own always-on-top panel that drags anywhere and
/// resizes at the image's aspect ratio. Keeps the panels alive until their close button is clicked.
@MainActor
final class PinController {

    private var panels: [NSPanel] = []

    /// Pins with its bottom-left corner at `origin`
    func pin(_ screenshot: Screenshot, at origin: CGPoint, on screen: NSScreen) {
        let panel = NSPanel(
            contentRect: Self.frame(for: screenshot.pointSize, at: origin, in: screen.visibleFrame),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // On once the pin has settled: a window shadow doesn't follow the fade
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentAspectRatio = screenshot.pointSize

        // The pin appears where the card was, which hands its corner over
        panel.animationBehavior = .none

        let presence = PanelPresence()
        let hostingView = NSHostingView(rootView: PinView(image: screenshot.image, presence: presence) { [weak self, weak panel] in
            guard let self, let panel else { return }
            close(panel, presence: presence)
        })
        // The panel's frame is the size; the image's intrinsic size would grow it to full pixels
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        panel.orderFront(nil)
        panels.append(panel)

        Task {
            try? await Task.sleep(for: PanelPresentation.exitDelay)
            guard panels.contains(where: { $0 === panel }), presence.isShown else { return }
            panel.hasShadow = true
            panel.invalidateShadow()
        }
    }

    /// The screenshot at its on-screen size, shrunk (never enlarged) to fit `visibleFrame`, with its
    /// bottom-left corner at `origin`, moved just enough to stay inside `visibleFrame`.
    nonisolated static func frame(for pointSize: CGSize, at origin: CGPoint, in visibleFrame: CGRect) -> CGRect {
        let scale = min(1, visibleFrame.width / pointSize.width, visibleFrame.height / pointSize.height)
        let size = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
        return CGRect(
            x: min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - size.width),
            y: min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - size.height),
            width: size.width,
            height: size.height
        )
    }

    /// Shrinks the pin back to its corner, then takes it off screen
    private func close(_ panel: NSPanel, presence: PanelPresence) {
        guard presence.isShown else { return }
        presence.isShown = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        Task {
            try? await Task.sleep(for: PanelPresentation.exitDelay)
            panel.orderOut(nil)
            panels.removeAll { $0 === panel }
        }
    }
}
