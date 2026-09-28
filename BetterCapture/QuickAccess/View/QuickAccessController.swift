//
//  QuickAccessController.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import AppKit
import OSLog
import SwiftUI

/// CleanShot-style floating thumbnail of a capture: copy, reveal, drag out, close.
///
/// Holds the output folder's security scope while shown, since drag and copy hand out the file URL
/// and sandboxed receivers only get access to it if we still have it when the URL is written.
@MainActor
final class QuickAccessController {

    nonisolated static let cardSize = CGSize(width: 240, height: 150)
    nonisolated static let margin: CGFloat = 16

    private let settings: SettingsStore
    private let hideCountdown = RecordingCountdown()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "QuickAccess")

    private var panel: NSPanel?
    private var fileURL: URL?
    private var loadTask: Task<Void, Never>?
    private var accessesOutputDirectory = false

    init(settings: SettingsStore) {
        self.settings = settings
    }

    /// Replaces any thumbnail showing.
    func show(fileURL: URL) {
        dismiss()

        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else {
            return
        }

        self.fileURL = fileURL
        accessesOutputDirectory = settings.startAccessingOutputDirectory()

        let maxPixelSize = max(Self.cardSize.width, Self.cardSize.height) * screen.backingScaleFactor
        loadTask = Task {
            let image = await ImageDownsampler.thumbnail(of: fileURL, maxPixelSize: maxPixelSize)
            guard !Task.isCancelled else { return }
            guard let image else {
                logger.error("Couldn't decode a thumbnail for \(fileURL.lastPathComponent)")
                dismiss()
                return
            }
            present(image: image, fileURL: fileURL, on: screen)
        }
    }

    /// Copies the full image (PNG + file URL) to the pasteboard, then dismisses.
    func copy() {
        guard let fileURL else { return }
        do {
            let png = try Data(contentsOf: fileURL)
            ImagePasteboard.copy(png: png, fileURL: fileURL)
            dismiss()
        } catch {
            logger.error("Couldn't read \(fileURL.lastPathComponent) to copy: \(error.localizedDescription)")
        }
    }

    func showInFinder() {
        guard let fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        dismiss()
    }

    /// Hovering pauses the hide timer; leaving restarts the full 6 s.
    ///
    /// ponytail: a drag held more than 6 s after the mouse leaves the panel closes it and releases
    /// the scope mid-drag; add drag-session tracking if that's reported.
    func setHovering(_ isHovering: Bool) {
        // A fading panel still reports the mouse leaving; that must not restart the timer
        guard panel != nil else { return }
        if isHovering {
            hideCountdown.cancel()
        } else {
            hideCountdown.start(seconds: 6) { [weak self] in
                self?.dismiss()
            }
        }
    }

    func dismiss() {
        loadTask?.cancel()
        loadTask = nil
        hideCountdown.cancel()

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
        fileURL = nil

        if accessesOutputDirectory {
            settings.stopAccessingOutputDirectory()
            accessesOutputDirectory = false
        }
    }

    /// Bottom-left of `visibleFrame`, inset by `margin`.
    nonisolated static func panelFrame(in visibleFrame: CGRect) -> CGRect {
        CGRect(origin: CGPoint(x: visibleFrame.minX + margin, y: visibleFrame.minY + margin), size: cardSize)
    }

    private func present(image: CGImage, fileURL: URL, on screen: NSScreen) {
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
        panel.contentView = NSHostingView(rootView: QuickAccessView(image: image, fileURL: fileURL, controller: self))
        panel.alphaValue = 0
        panel.orderFront(nil)
        self.panel = panel

        NSAnimationContext.runAnimationGroup { _ in
            panel.animator().alphaValue = 1
        }

        hideCountdown.start(seconds: 6) { [weak self] in
            self?.dismiss()
        }
    }
}
