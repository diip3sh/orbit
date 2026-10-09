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
/// The card stays until it's closed, saved or pinned, or the next screenshot replaces it. The last one to go
/// stays in memory for Restore Last Screenshot.
@MainActor
@Observable
final class QuickAccessController {

    /// The largest card. A card takes its screenshot's shape inside it (`cardSize(for:)`)
    nonisolated static let maxCardSize = CGSize(width: 260, height: 220)

    /// The smallest card: room for Copy ⌘C and Save ⌘S side by side, and the corner buttons above them
    nonisolated static let minCardSize = CGSize(width: 200, height: 120)

    /// The surface's edge around the preview, which is also where the card is dragged
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

    /// The editor's tool strip, with Copy and Save at its end
    nonisolated static let annotationBarHeight: CGFloat = 32

    /// The narrowest editor: room for the tool strip (about 570 pt) and Copy and Save (about 200)
    nonisolated static let minAnnotationWidth: CGFloat = 800

    /// The card grown into the editor (spec 0015) for a shot of `pointSize`: the shot at its size on screen, shrunk to
    /// fit `visibleFrame` less the margins, the edge and the strip, and at least `minAnnotationWidth`.
    nonisolated static func annotationCardSize(for pointSize: CGSize, in visibleFrame: CGRect) -> CGSize {
        let bars = annotationBarHeight + inset
        let roomWidth = visibleFrame.width - 2 * margin - 2 * inset
        let roomHeight = visibleFrame.height - 2 * margin - 2 * inset - bars
        guard pointSize.width > 0, pointSize.height > 0, roomWidth > 0, roomHeight > 0 else { return maxCardSize }
        let scale = min(1, roomWidth / pointSize.width, roomHeight / pointSize.height)
        let width = (pointSize.width * scale).rounded() + 2 * inset
        let height = (pointSize.height * scale).rounded() + 2 * inset + bars
        return CGSize(width: max(width, min(minAnnotationWidth, visibleFrame.width - 2 * margin)), height: height)
    }

    /// `frame` moved the least that puts it inside `visibleFrame`
    nonisolated static func onScreen(_ frame: CGRect, in visibleFrame: CGRect) -> CGRect {
        CGRect(
            x: min(max(frame.minX, visibleFrame.minX), max(visibleFrame.maxX - frame.width, visibleFrame.minX)),
            y: min(max(frame.minY, visibleFrame.minY), max(visibleFrame.maxY - frame.height, visibleFrame.minY)),
            width: frame.width, height: frame.height
        )
    }

    /// The screenshot of the last card that went away (closed, copied, saved, pinned or replaced), for `restoreClosed()`
    private(set) var closedScreenshot: Screenshot?

    @ObservationIgnored private let save: @MainActor (Screenshot) async -> Bool
    @ObservationIgnored private let didCopy: @MainActor (Screenshot) async -> Void
    @ObservationIgnored private let background: @MainActor () -> ScreenshotBackground
    @ObservationIgnored let pins = PinController()
    @ObservationIgnored private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "QuickAccess")

    @ObservationIgnored private var panel: NSPanel?
    @ObservationIgnored private var model: QuickAccessViewModel?
    /// The card's corner that stays put when it grows, shrinks or refits to a reshaped shot
    @ObservationIgnored private var anchor = UnitPoint.bottomLeading
    /// The screenshot shown, or about to be once its preview is drawn
    @ObservationIgnored private var current: Screenshot?
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    /// Panels playing their exit; `hide()` takes them off at once too, so none lands in a capture
    @ObservationIgnored private var leaving: [NSPanel] = []

    /// - Parameters:
    ///   - save: Saves a screenshot into the output folder, returning whether it did
    ///   - didCopy: Told after a screenshot was put on the pasteboard
    ///   - background: The background a card's Add Background puts the shot on (Settings → Screenshots)
    init(
        save: @escaping @MainActor (Screenshot) async -> Bool, didCopy: @escaping @MainActor (Screenshot) async -> Void,
        background: @escaping @MainActor () -> ScreenshotBackground
    ) {
        self.save = save
        self.didCopy = didCopy
        self.background = background
    }

    /// Replaces any card showing.
    /// - Parameter besidePointer: Whether an area capture's card opens where the drag ended; otherwise it opens in the
    ///   screen's corner.
    func show(_ screenshot: Screenshot, besidePointer: Bool = true) {
        dismiss()
        current = screenshot

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
            let model = QuickAccessViewModel(
                screenshot: screenshot, preview: preview, previewPixelSize: maxPixelSize, save: save, didCopy: didCopy, background: background
            )
            present(model, on: screen, pointer: besidePointer ? pointer : nil)
        }
    }

    /// Does what a `reco://` link asked for in place of the card, leaving any card showing as it is. The shot is then
    /// the one to restore; when copying or saving fails, its card opens instead.
    func follow(_ followUp: ScreenshotFollowUp, with screenshot: Screenshot) async {
        closedScreenshot = screenshot
        switch followUp {
        case .copy:
            do {
                ImagePasteboard.copy(png: try await ScreenshotService.pngData(of: screenshot.image))
                await didCopy(screenshot)
            } catch {
                logger.error("Couldn't encode the screenshot to copy: \(error.localizedDescription)")
                show(screenshot)
            }
        case .save:
            if await !save(screenshot) {
                show(screenshot)
            }
        case .pin:
            let pointer = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) }) ?? NSScreen.main else { return }
            // An area stays where it was taken; anything else pins where its card would open
            pins.pin(screenshot, at: screenshot.region?.origin ?? Self.panelFrame(in: screen.visibleFrame, size: .zero).origin, on: screen)
        }
    }

    /// Brings back the last card that went away, in the screen's corner; a card showing takes its place in memory.
    func restoreClosed() {
        guard let closedScreenshot else { return }
        show(closedScreenshot, besidePointer: false)
    }

    func dismiss() {
        loadTask?.cancel()
        loadTask = nil
        if let current {
            // The card's shot, since hiding sensitive info replaces it
            closedScreenshot = model?.screenshot ?? current
            self.current = nil
        }

        // A save finishing after its card went away must not close the next card
        model?.onClose = nil
        model?.onPin = nil
        model?.onReshape = nil
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

    /// - Parameter pointer: Where an area capture's drag ended, to open beside; nil opens in the screen's corner
    private func present(_ model: QuickAccessViewModel, on screen: NSScreen, pointer: CGPoint?) {
        model.onClose = { [weak self] in self?.dismiss() }
        model.onPin = { [weak self] in self?.pin() }
        model.onReshape = { [weak self] in self?.refit() }

        let size = Self.cardSize(for: model.screenshot.pointSize)
        model.cardSize = size
        let frame: CGRect
        var grownFrom: CGPoint?
        if let pointer, let region = model.screenshot.region {
            frame = Self.panelFrame(in: screen.visibleFrame, size: size, pointer: pointer, awayFrom: region)
            grownFrom = pointer
        } else {
            frame = Self.panelFrame(in: screen.visibleFrame, size: size)
        }
        let panel = QuickAccessPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // No window shadow: it outlines the whole rectangle around the rounded card, which has its own edge
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
        anchor = Self.anchor(for: frame, pointer: grownFrom)
        panel.contentView = NSHostingView(rootView: QuickAccessView(model: model, dragger: dragger, anchor: anchor).themed())
        // Key, so ⌘C and ⌘S copy and save the new screenshot until another window is clicked
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        self.model = model
    }

    /// The card at `size`, moved so the corner at `anchor` (top at y 0) stays where it is.
    nonisolated static func refitted(_ frame: CGRect, to size: CGSize, anchor: UnitPoint) -> CGRect {
        CGRect(
            x: frame.minX + (frame.width - size.width) * anchor.x,
            y: frame.minY + (frame.height - size.height) * (1 - anchor.y),
            width: size.width, height: size.height
        )
    }

    /// Fits the card to its shot's new shape (a background added or taken off) or to the editor, keeping the corner it
    /// grew from in place, moved on screen where it wouldn't fit.
    private func refit() {
        guard let model, let panel, let screen = panel.screen ?? NSScreen.main else { return }
        let size = model.isAnnotating
            ? Self.annotationCardSize(for: model.annotation?.pointSize ?? model.screenshot.pointSize, in: screen.visibleFrame)
            : Self.cardSize(for: model.screenshot.pointSize)
        model.cardSize = size
        let frame = Self.onScreen(Self.refitted(panel.frame, to: size, anchor: anchor), in: screen.visibleFrame)
        panel.setFrame(frame, display: true)
    }

    /// Pins the screenshot with its bottom-left where the card is
    private func pin() {
        guard let model, let panel, let screen = panel.screen ?? NSScreen.main else { return }
        pins.pin(model.screenshot, at: panel.frame.origin, on: screen)
    }
}
