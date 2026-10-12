//
//  CaptureSourceLoader.swift
//  Reco
//

import AppKit
@preconcurrency import ScreenCaptureKit

/// Lists the windows or displays the picker offers, each with the filter that records it, and draws
/// their thumbnails with ScreenCaptureKit.
@MainActor
enum CaptureSourceLoader {

    struct Entry {
        let source: CaptureSource
        /// What a recording of it captures; Settings' exclusions are applied when the take starts
        let filter: SCContentFilter
        /// What its thumbnail shows: a display without Reco's own windows over it
        let thumbnailFilter: SCContentFilter
    }

    /// Thumbnails are drawn this many pixels across at most: a 2× tile
    static let thumbnailPixelWidth = Int(CaptureSourceGrid.tileWidth * 2)

    static func entries(of kind: CaptureSource.Kind) async throws -> [Entry] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        switch kind {
        case .window:
            return windows(in: content)
        case .display:
            return displays(in: content)
        }
    }

    private static func windows(in content: SCShareableContent) -> [Entry] {
        let ownBundleID = Bundle.main.bundleIdentifier
        return content.windows
            .filter {
                CaptureSource.offers(
                    layer: $0.windowLayer,
                    frame: $0.frame,
                    bundleID: $0.owningApplication?.bundleIdentifier,
                    isOnScreen: $0.isOnScreen,
                    ownBundleID: ownBundleID
                )
            }
            .map { window in
                let appName = window.owningApplication?.applicationName ?? ""
                let filter = SCContentFilter(desktopIndependentWindow: window)
                return Entry(
                    source: CaptureSource(
                        id: window.windowID,
                        title: CaptureSource.title(windowTitle: window.title, appName: appName),
                        subtitle: appName,
                        processID: window.owningApplication?.processID
                    ),
                    filter: filter,
                    thumbnailFilter: filter
                )
            }
    }

    private static func displays(in content: SCShareableContent) -> [Entry] {
        let reco = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        return content.displays.enumerated().map { index, display in
            let name = NSScreen.screens.first { $0.displayID == display.displayID }?.localizedName ?? "Display \(index + 1)"
            return Entry(
                source: CaptureSource(id: display.displayID, title: name, subtitle: "\(display.width) × \(display.height)", processID: nil),
                filter: SCContentFilter(display: display, excludingWindows: []),
                thumbnailFilter: SCContentFilter(display: display, excludingApplications: reco, exceptingWindows: [])
            )
        }
    }

    /// A small picture of what `filter` shows now, without the cursor
    static func thumbnail(of filter: SCContentFilter) async -> CGImage? {
        let rect = filter.contentRect
        guard rect.width > 0, rect.height > 0 else { return nil }
        let width = min(thumbnailPixelWidth, Int(rect.width * CGFloat(filter.pointPixelScale)))
        let config = SCStreamConfiguration()
        config.width = width
        config.height = max(1, Int((CGFloat(width) * rect.height / rect.width).rounded()))
        // Window captures don't resize content to the configured size on their own (see CaptureEngine)
        config.scalesToFit = filter.style == .window
        config.showsCursor = false
        return try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}
