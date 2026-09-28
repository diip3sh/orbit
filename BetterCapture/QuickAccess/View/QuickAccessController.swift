//
//  QuickAccessController.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import AppKit
import OSLog
import SwiftUI

/// Shows the Quick Access card for the last screenshot in a floating panel, and owns the pins made from it.
///
/// The card stays until it's closed, saved or pinned, or the next screenshot replaces it.
@MainActor
final class QuickAccessController {

    nonisolated static let cardSize = CGSize(width: 230, height: 210)
    nonisolated static let margin: CGFloat = 16

    private let save: @MainActor (Screenshot) async -> Bool
    private let pins = PinController()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "QuickAccess")

    private var panel: NSPanel?
    private var model: QuickAccessViewModel?
    private var loadTask: Task<Void, Never>?

    /// - Parameter save: Saves a screenshot into the output folder, returning whether it did
    init(save: @escaping @MainActor (Screenshot) async -> Bool) {
        self.save = save
    }

    /// Replaces any card showing.
    func show(_ screenshot: Screenshot) {
        dismiss()

        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else {
            return
        }

        // 2× the card, so the preview stays sharp without another full-size copy
        let maxPixelSize = max(Self.cardSize.width, Self.cardSize.height) * screen.backingScaleFactor
        loadTask = Task {
            let preview = await ImageDownsampler.thumbnail(of: screenshot.image, maxPixelSize: maxPixelSize)
            guard !Task.isCancelled else { return }
            guard let preview else {
                logger.error("Couldn't draw a preview of the screenshot")
                return
            }
            present(QuickAccessViewModel(screenshot: screenshot, preview: preview, save: save), on: screen)
        }
    }

    func dismiss() {
        loadTask?.cancel()
        loadTask = nil

        // A save finishing after its card went away must not close the next card
        model?.onClose = nil
        model?.onPin = nil
        model?.removeDragFile()
        model = nil

        if let panel {
            panel.ignoresMouseEvents = true
            NSAnimationContext.runAnimationGroup { _ in
                panel.animator().alphaValue = 0
            } completionHandler: {
                MainActor.assumeIsolated {
                    panel.orderOut(nil)
                }
            }
        }
        panel = nil
    }

    /// Takes the card off screen at once, keeping it for `restore()`
    func hide() {
        panel?.orderOut(nil)
    }

    /// Brings back a card taken away by `hide()`, where it was
    func restore() {
        panel?.orderFront(nil)
    }

    /// Bottom-left of `visibleFrame`, inset by `margin`.
    nonisolated static func panelFrame(in visibleFrame: CGRect) -> CGRect {
        CGRect(origin: CGPoint(x: visibleFrame.minX + margin, y: visibleFrame.minY + margin), size: cardSize)
    }

    private func present(_ model: QuickAccessViewModel, on screen: NSScreen) {
        model.onClose = { [weak self] in self?.dismiss() }
        model.onPin = { [weak self] in self?.pin() }

        let panel = NSPanel(
            contentRect: Self.panelFrame(in: screen.visibleFrame),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        // Dark translucent card in either system appearance
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = NSHostingView(rootView: QuickAccessView(model: model))
        panel.alphaValue = 0
        panel.orderFront(nil)
        self.panel = panel
        self.model = model

        NSAnimationContext.runAnimationGroup { _ in
            panel.animator().alphaValue = 1
        }
    }

    /// Pins the screenshot with its bottom-left where the card is
    private func pin() {
        guard let model, let panel, let screen = panel.screen ?? NSScreen.main else { return }
        pins.pin(model.screenshot, at: panel.frame.origin, on: screen)
    }
}
