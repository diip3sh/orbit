//
//  QuickAccessController.swift
//  Reco
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

    /// The largest card. A card takes its screenshot's shape inside it (`cardSize(for:)`)
    nonisolated static let maxCardSize = CGSize(width: 260, height: 220)

    /// The smallest card: room for Copy ⌘C and Save ⌘S side by side, and the corner buttons above them
    nonisolated static let minCardSize = CGSize(width: 200, height: 120)

    /// The glass edge around the preview, which is also where the card is dragged
    nonisolated static let inset: CGFloat = 8

    /// The card for a screenshot of `pointSize`: the shot fitted inside `maxCardSize` less the edge,
    /// never larger than it was on screen, and no smaller than `minCardSize`.
    nonisolated static func cardSize(for pointSize: CGSize) -> CGSize {
        guard pointSize.width > 0, pointSize.height > 0 else { return maxCardSize }
        let roomWidth = maxCardSize.width - 2 * inset
        let roomHeight = maxCardSize.height - 2 * inset
        let scale = min(1, roomWidth / pointSize.width, roomHeight / pointSize.height)
        let width = (pointSize.width * scale).rounded() + 2 * inset
        let height = (pointSize.height * scale).rounded() + 2 * inset
        return CGSize(width: max(minCardSize.width, width), height: max(minCardSize.height, height))
    }

    nonisolated static let margin: CGFloat = 16

    private let save: @MainActor (Screenshot) async -> Bool
    private let pins = PinController()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "QuickAccess")

    private var panel: NSPanel?
    private var model: QuickAccessViewModel?
    private var loadTask: Task<Void, Never>?

    /// Panels playing their exit; `hide()` takes them off at once too, so none lands in a capture
    private var leaving: [NSPanel] = []

    /// - Parameter save: Saves a screenshot into the output folder, returning whether it did
    init(save: @escaping @MainActor (Screenshot) async -> Bool) {
        self.save = save
    }

    /// Replaces any card showing.
    func show(_ screenshot: Screenshot) {
        dismiss()

        // After an area capture the pointer is still where the drag ended
        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) }) ?? NSScreen.main else {
            return
        }

        // 2× the card, so the preview stays sharp without another full-size copy
        let maxPixelSize = max(Self.maxCardSize.width, Self.maxCardSize.height) * screen.backingScaleFactor
        loadTask = Task {
            let preview = await ImageDownsampler.thumbnail(of: screenshot.image, maxPixelSize: maxPixelSize)
            guard !Task.isCancelled else { return }
            guard let preview else {
                logger.error("Couldn't draw a preview of the screenshot")
                return
            }
            present(QuickAccessViewModel(screenshot: screenshot, preview: preview, save: save), on: screen, pointer: pointer)
        }
    }

    func dismiss() {
        loadTask?.cancel()
        loadTask = nil

        // A save finishing after its card went away must not close the next card
        model?.onClose = nil
        model?.onPin = nil
        model?.removeDragFile()
        model?.isPresented = false
        model = nil

        if let panel {
            // The card shrinks back to the corner it grew from
            panel.ignoresMouseEvents = true
            leaving.append(panel)
            Task {
                try? await Task.sleep(for: PanelPresentation.exitDelay)
                panel.orderOut(nil)
                leaving.removeAll { $0 === panel }
            }
        }
        panel = nil
    }

    /// Takes the card off screen at once, keeping it for `restore()`
    func hide() {
        panel?.orderOut(nil)
        for panel in leaving {
            panel.orderOut(nil)
        }
    }

    /// Brings back a card taken away by `hide()`, where it was
    func restore() {
        panel?.orderFront(nil)
    }

    /// Bottom-left of `visibleFrame`, inset by `margin`.
    nonisolated static func panelFrame(in visibleFrame: CGRect, size: CGSize) -> CGRect {
        CGRect(origin: CGPoint(x: visibleFrame.minX + margin, y: visibleFrame.minY + margin), size: size)
    }

    /// The corner of a card at `frame` nearest `pointer`, where it grows from and shrinks back to; the
    /// bottom-left without a pointer, for the card in the screen's corner.
    nonisolated static func anchor(for frame: CGRect, pointer: CGPoint?) -> UnitPoint {
        guard let pointer else { return .bottomLeading }
        return UnitPoint(x: pointer.x >= frame.midX ? 1 : 0, y: pointer.y >= frame.midY ? 0 : 1)
    }

    /// Beside `pointer`, a `margin` away on its sides facing away from the captured `region`, so the card
    /// opens where the drag ended without covering the shot. Slid back on screen where it wouldn't fit.
    nonisolated static func panelFrame(in visibleFrame: CGRect, size: CGSize, pointer: CGPoint, awayFrom region: CGRect) -> CGRect {
        let bounds = visibleFrame.insetBy(dx: margin, dy: margin)
        let left = pointer.x >= region.midX ? pointer.x + margin : pointer.x - margin - size.width
        let bottom = pointer.y >= region.midY ? pointer.y + margin : pointer.y - margin - size.height
        let origin = CGPoint(
            x: min(max(left, bounds.minX), bounds.maxX - size.width),
            y: min(max(bottom, bounds.minY), bounds.maxY - size.height)
        )
        return CGRect(origin: origin, size: size)
    }

    private func present(_ model: QuickAccessViewModel, on screen: NSScreen, pointer: CGPoint) {
        model.onClose = { [weak self] in self?.dismiss() }
        model.onPin = { [weak self] in self?.pin() }

        let visibleFrame = screen.visibleFrame
        let region = model.screenshot.region
        let size = Self.cardSize(for: model.screenshot.pointSize)
        let frame = region.map { Self.panelFrame(in: visibleFrame, size: size, pointer: pointer, awayFrom: $0) }
            ?? Self.panelFrame(in: visibleFrame, size: size)
        let panel = QuickAccessPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // No window shadow: it outlines the whole rectangle around the rounded glass, which has its own edge
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        // The card animates itself, which the system's own window animation would only distort
        panel.animationBehavior = .none

        let dragger = PanelDragger()
        dragger.panel = panel
        dragger.onFlick = { [weak model] in model?.close() }
        let anchor = Self.anchor(for: frame, pointer: region == nil ? nil : pointer)
        panel.contentView = NSHostingView(rootView: QuickAccessView(model: model, dragger: dragger, anchor: anchor, size: size))
        // Key, so ⌘C and ⌘S copy and save the new screenshot until another window is clicked
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        self.model = model
    }

    /// Pins the screenshot with its bottom-left where the card is
    private func pin() {
        guard let model, let panel, let screen = panel.screen ?? NSScreen.main else { return }
        pins.pin(model.screenshot, at: panel.frame.origin, on: screen)
    }
}
