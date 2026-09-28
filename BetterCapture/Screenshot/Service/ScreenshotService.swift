//
//  ScreenshotService.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import AppKit
import ImageIO
@preconcurrency import ScreenCaptureKit
import UniformTypeIdentifiers

/// Captures one still with ScreenCaptureKit and saves it as PNG into the recordings' output folder
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

    /// The ScreenCaptureKit display showing a screen
    func display(for screen: NSScreen) async throws -> SCDisplay {
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.selectedDisplayDisconnected
        }
        return display
    }

    /// Captures at native resolution with the user's visibility settings and saves a PNG.
    /// - Parameter sourceRect: The area to capture (display points, top-left origin), or nil for the whole filter
    /// - Returns: The saved file
    func capture(_ filter: SCContentFilter, sourceRect: CGRect?, settings: SettingsStore) async throws -> URL {
        let filter = try await contentFilterService.applySettings(to: filter, settings: settings)
        let pixelSize = CaptureSizeCalculator.videoSize(
            contentRect: sourceRect ?? filter.contentRect,
            scale: filter.captureScale,
            useNativeResolution: true
        )
        let configuration = Self.configuration(
            pixelSize: pixelSize,
            sourceRect: sourceRect,
            isWindowCapture: filter.style == .window,
            settings: settings
        )
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)

        let didStart = settings.startAccessingOutputDirectory()
        defer {
            if didStart { settings.stopAccessingOutputDirectory() }
        }
        let url = Self.outputURL(in: settings.outputDirectory, date: .now)
        try await Self.writePNG(image, to: url)
        return url
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

    /// `BetterCapture_Screenshot_<timestamp>.png`
    static func outputURL(in directory: URL, date: Date) -> URL {
        directory.appending(path: SettingsStore.filename(prefix: "BetterCapture_Screenshot", fileExtension: "png", date: date))
    }

    /// Encodes off the main actor. ImageIO embeds the image's colour space as an ICC profile.
    @concurrent
    nonisolated private static func writePNG(_ image: CGImage, to url: URL) async throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}
