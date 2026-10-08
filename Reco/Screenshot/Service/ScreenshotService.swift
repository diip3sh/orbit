//
//  ScreenshotService.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import AppKit
import ImageIO
@preconcurrency import ScreenCaptureKit
import UniformTypeIdentifiers

/// Captures one still with ScreenCaptureKit, and writes screenshots as PNG, or HEIC for HDR
@MainActor
final class ScreenshotService {

    private let contentFilterService = ContentFilterService()

    /// Throws, after prompting, when Screen Recording isn't granted, the same way a recording start does
    func verifyPermission() throws {
        guard contentFilterService.hasScreenRecordingPermission() else {
            contentFilterService.requestScreenRecordingPermission()
            throw CaptureError.screenRecordingPermissionDenied
        }
    }

    /// A screen as the user sees it, Reco's windows and menus included; without the menu bar popover
    /// when the screenshot was started from it (it may still be fading out)
    func screenFilter(for screen: NSScreen, leavingPopover: Bool) async throws -> SCContentFilter {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.displayID == screen.displayID }) else {
            throw CaptureError.selectedDisplayDisconnected
        }
        return Self.screenFilter(display, content: content, leavingPopover: leavingPopover)
    }

    /// Every display as it is now, by display ID, for an area cut from a frozen screen
    func captureDisplays(leavingPopover: Bool, settings: SettingsStore) async throws -> [CGDirectDisplayID: Screenshot] {
        let content = try await SCShareableContent.current
        var shots: [CGDirectDisplayID: Screenshot] = [:]
        // ponytail: one display after another; capture them together if several displays make the start slow
        for display in content.displays {
            shots[display.displayID] = try await capture(Self.screenFilter(display, content: content, leavingPopover: leavingPopover), sourceRect: nil, settings: settings)
        }
        return shots
    }

    private static func screenFilter(_ display: SCDisplay, content: SCShareableContent, leavingPopover: Bool) -> SCContentFilter {
        // SwiftUI's `MenuBarExtraWindow` holds the popover
        let popovers = !leavingPopover ? [] : Set(NSApp.windows.filter { String(describing: type(of: $0)).contains("MenuBarExtra") }.map(\.windowNumber))
        let filter = SCContentFilter(display: display, excludingWindows: content.windows.filter { popovers.contains(Int($0.windowID)) })
        filter.includeMenuBar = true
        return filter
    }

    /// Captures at native resolution exactly what the filter shows: unlike recordings, screenshots
    /// don't hide the wallpaper, Dock or Reco, since they're of what the user sees. Nothing is written.
    /// - Parameter sourceRect: The area to capture (display points, top-left origin), or nil for the whole filter
    func capture(_ filter: SCContentFilter, sourceRect: CGRect?, settings: SettingsStore) async throws -> Screenshot {
        let scale = filter.captureScale
        let pixelSize = CaptureSizeCalculator.videoSize(
            contentRect: sourceRect ?? filter.contentRect,
            scale: scale,
            useNativeResolution: true
        )
        let configuration = Self.configuration(
            pixelSize: pixelSize,
            sourceRect: sourceRect,
            isWindowCapture: filter.style == .window,
            settings: settings
        )
        // ponytail: windows stay SDR; the HDR configuration has no `scalesToFit`, which window captures need
        if #available(macOS 26.0, *), settings.capturesHDRScreenshots, filter.style == .display {
            let output = try await SCScreenshotManager.captureScreenshot(
                contentFilter: filter,
                configuration: Self.hdrConfiguration(pixelSize: pixelSize, sourceRect: sourceRect, settings: settings)
            )
            // macOS 27.0 hands the HDR picture over as `sdrImage`, and no `hdrImage` even for `.bothSDRAndHDR`
            // (measured 2026-10-08), so one HDR capture is asked for and the SDR one is drawn from it
            guard let hdrImage = output.hdrImage ?? output.sdrImage, let image = Self.standardRange(of: hdrImage) else {
                throw CocoaError(.fileReadUnknown)
            }
            return Screenshot(image: image, scale: scale, date: .now, hdrImage: hdrImage)
        }
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return Screenshot(image: image, scale: scale, date: .now)
    }

    /// Writes the screenshot into `directory` (`SettingsStore.screenshotDirectory`)
    /// - Returns: The saved file, `Reco_Screenshot_<capture time>.png` (`.heic` for HDR)
    func save(_ screenshot: Screenshot, in directory: URL) async throws -> URL {
        let url = directory.appending(path: screenshot.filename)
        try await Self.write(screenshot, to: url)
        return url
    }

    /// The same as `configuration(…)` for a display, plus both SDR and HDR images
    @available(macOS 26.0, *)
    static func hdrConfiguration(pixelSize: CGSize, sourceRect: CGRect?, settings: SettingsStore) -> SCScreenshotConfiguration {
        let config = SCScreenshotConfiguration()
        config.width = Int(pixelSize.width)
        config.height = Int(pixelSize.height)
        if let sourceRect {
            config.sourceRect = sourceRect
        }
        config.showsCursor = settings.showCursor
        config.ignoreShadows = !settings.showWindowShadows
        config.dynamicRange = .hdr
        return config
    }

    /// The picture in 8-bit sRGB, what is brighter than white clipped to white, as an SDR capture has it
    nonisolated static func standardRange(of image: CGImage) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB), let context = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    /// Native pixels; cursor and window shadows as the user set them for recordings
    static func configuration(pixelSize: CGSize, sourceRect: CGRect?, isWindowCapture: Bool, settings: SettingsStore) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = Int(pixelSize.width)
        config.height = Int(pixelSize.height)
        if let sourceRect {
            config.sourceRect = sourceRect
        }
        // Window captures don't resize content to the configured size on their own (see CaptureEngine)
        config.scalesToFit = isWindowCapture
        // Not `capturesCursor`: that hides the cursor for the editor to redraw, and screenshots have no editor
        config.showsCursor = settings.showCursor
        config.ignoreShadowsDisplay = !settings.showWindowShadows
        config.ignoreShadowsSingleWindow = !settings.showWindowShadows
        return config
    }

    /// Encodes and writes off the main actor, creating the folder: a PNG, or with an HDR image an HEIC whose SDR
    /// base and ISO gain map show it as bright as captured where the screen allows, and as the SDR image elsewhere
    @concurrent
    nonisolated static func write(_ screenshot: Screenshot, to url: URL) async throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let hdrImage = screenshot.hdrImage {
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.heic.identifier as CFString, 1, nil)
            try encode(hdrImage, into: destination, options: [kCGImageDestinationEncodeRequest: kCGImageDestinationEncodeToISOGainmap])
        } else {
            try encode(screenshot.image, into: CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        }
    }

    /// Encodes off the main actor, for the clipboard
    @concurrent
    nonisolated static func pngData(of image: CGImage) async throws -> Data {
        let data = NSMutableData()
        try encode(image, into: CGImageDestinationCreateWithData(data as CFMutableData, UTType.png.identifier as CFString, 1, nil))
        return data as Data
    }

    /// ImageIO embeds the image's colour space as an ICC profile
    nonisolated private static func encode(_ image: CGImage, into destination: CGImageDestination?, options: [CFString: Any] = [:]) throws {
        guard let destination else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}
