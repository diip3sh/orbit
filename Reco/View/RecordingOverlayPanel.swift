//
//  RecordingOverlayPanel.swift
//  Reco
//
//  Created by Joshua Sattler on 14.03.26.
//

import AppKit
import SwiftUI

// MARK: - Panel

/// A borderless, non-activating floating panel for the recording overlay. Its content draws its
/// own glass (`RecordingOverlayView`).
private final class RecordingOverlayNSPanel: NSPanel {
    init(contentRect: CGRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        // No window shadow: it outlines the whole rectangle around the rounded glass, which has its own edge
        hasShadow = false
        level = .floating
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // The view animates itself, which the system's own window animation would only distort
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
}

// MARK: - Coordinator

/// Manages the lifecycle of the recording overlay panel.
@MainActor
final class RecordingOverlayCoordinator {

    private var panel: RecordingOverlayNSPanel?
    private weak var viewModel: RecorderViewModel?
    private let presence = PanelPresence()

    /// Takes the panel off screen once its exit has played; cancelled by a `show()` meanwhile.
    private var removal: Task<Void, Never>?

    // MARK: - Public API

    /// Shows the recording overlay anchored below the menu bar status item on the given screen.
    /// If `screen` is nil the overlay falls back to the screen containing the status item.
    /// Starts the live preview automatically. Drops from the status item; shown again during its
    /// exit, it turns round from where it is.
    func show(viewModel: RecorderViewModel, screen: NSScreen? = nil) {
        let isLeaving = removal != nil
        removal?.cancel()
        removal = nil

        // If already showing, just bring to front
        if let existing = panel {
            presence.isShown = true
            existing.ignoresMouseEvents = false
            existing.makeKeyAndOrderFront(nil)
            if isLeaving {
                self.viewModel = viewModel
                startPreview(of: viewModel)
            }
            return
        }

        self.viewModel = viewModel
        presence.isShown = true

        let panelWidth: CGFloat = 280
        let panelHeight: CGFloat = 270

        let origin = overlayOrigin(width: panelWidth, height: panelHeight, preferredScreen: screen)
        let contentRect = CGRect(x: origin.x, y: origin.y, width: panelWidth, height: panelHeight)

        let newPanel = RecordingOverlayNSPanel(contentRect: contentRect)
        newPanel.contentView = NSHostingView(rootView: RecordingOverlayView(viewModel: viewModel, presence: presence) { [weak self] in
            self?.dismiss()
        })
        newPanel.makeKeyAndOrderFront(nil)
        panel = newPanel

        // Auto-start live preview
        startPreview(of: viewModel)
    }

    /// Stops the live preview at once and takes the overlay away after its exit.
    func dismiss() {
        guard let panel, removal == nil else { return }
        presence.isShown = false
        panel.ignoresMouseEvents = true

        if let viewModel {
            Task {
                await viewModel.stopPreview()
            }
        }
        viewModel = nil

        removal = Task {
            try? await Task.sleep(for: PanelPresentation.exitDelay)
            guard !Task.isCancelled else { return }
            panel.orderOut(nil)
            self.panel = nil
            removal = nil
        }
    }

    private func startPreview(of viewModel: RecorderViewModel) {
        Task {
            await viewModel.startPreview()
        }
    }

    // MARK: - Positioning

    /// Determines the screen-coordinate origin (bottom-left) for the panel.
    ///
    /// Priority:
    /// 1. If a `preferredScreen` is supplied, anchor below that screen's menu bar status item
    ///    (found via the NSStatusBarWindow heuristic restricted to that screen), or fall back
    ///    to the top-right corner of that screen.
    /// 2. Otherwise fall back to the screen containing the status item window, or main screen.
    private func overlayOrigin(width: CGFloat, height: CGFloat, preferredScreen: NSScreen?) -> CGPoint {
        let gap: CGFloat = 4
        let menuBarThickness = NSStatusBar.system.thickness

        // Try to find the NSStatusBarWindow on the preferred screen (or any screen as fallback).
        // The MenuBarExtra(.window) style creates an NSStatusBarWindow whose frame sits in the
        // menu bar area; its class name contains "StatusBar".
        let targetScreen = preferredScreen ?? NSScreen.main ?? NSScreen.screens[0]

        if let statusWindow = NSApp.windows.first(where: {
            String(describing: type(of: $0)).contains("StatusBar") &&
            targetScreen.frame.contains($0.frame.origin)
        }) {
            let frame = statusWindow.frame
            let originX = max(targetScreen.frame.minX, min(frame.midX - width / 2, targetScreen.frame.maxX - width))
            let originY = frame.minY - height - gap
            return CGPoint(x: originX, y: originY)
        }

        // Fallback: top-right corner of the target screen, just below the menu bar.
        let originX = targetScreen.frame.maxX - width - 16
        let originY = targetScreen.frame.maxY - menuBarThickness - height - gap
        return CGPoint(x: originX, y: originY)
    }
}
