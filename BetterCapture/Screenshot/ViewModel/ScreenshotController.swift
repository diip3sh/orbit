//
//  ScreenshotController.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import AppKit
import OSLog
@preconcurrency import ScreenCaptureKit

/// Screenshots of an area, a window or the screen under the cursor, kept in memory until saved as PNG next to recordings
@MainActor
@Observable
final class ScreenshotController {

    /// Called as a screenshot starts, before anything is selected or captured
    @ObservationIgnored var onWillCapture: (@MainActor () -> Void)?

    /// Called as a screenshot ends, with nil when it was cancelled or failed; nothing is written until `save(_:)`
    @ObservationIgnored var onDidCapture: (@MainActor (Screenshot?) -> Void)?

    /// Whether a screenshot is being selected or captured
    private(set) var isCapturing = false

    private let settings: SettingsStore
    private let notificationService: NotificationService
    private let service = ScreenshotService()
    private let areaSelectionOverlay = AreaSelectionOverlay()
    private let windowPicker = WindowPicker()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "ScreenshotController")

    init(settings: SettingsStore, notificationService: NotificationService) {
        self.settings = settings
        self.notificationService = notificationService
    }

    /// Screenshots wait for the recorder: none while it records, stops or counts down, and only one at a time
    static func canCapture(recorderState: RecorderViewModel.RecordingState, isCountingDown: Bool, isCapturing: Bool) -> Bool {
        recorderState == .idle && !isCountingDown && !isCapturing
    }

    func canCapture(alongside recorder: RecorderViewModel) -> Bool {
        Self.canCapture(recorderState: recorder.state, isCountingDown: recorder.countdown.isRunning, isCapturing: isCapturing)
    }

    func captureArea() async {
        await capture {
            guard let selection = await areaSelectionOverlay.present(confirmsOnRelease: true) else { return nil }
            let display = try await service.display(for: selection.screen)
            let sourceRect = CaptureSizeCalculator.sourceRect(
                for: selection.screenRect,
                in: selection.screen.frame,
                scale: selection.screen.backingScaleFactor
            )
            let filter = SCContentFilter(display: display, excludingWindows: [])
            return Target(filter: filter, sourceRect: sourceRect, region: selection.screenRect)
        }
    }

    func captureWindow() async {
        await capture {
            guard let filter = await windowPicker.pick() else { return nil }
            return Target(filter: filter)
        }
    }

    func captureScreen() async {
        await capture {
            // ponytail: fixed wait for the popover's close animation, which only matters with Show
            // BetterCapture on (otherwise its windows are filtered out). Measure and tune, or wait on the window.
            try? await Task.sleep(for: .milliseconds(250))
            let mouse = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return nil }
            return Target(filter: SCContentFilter(display: try await service.display(for: screen), excludingWindows: []))
        }
    }

    /// Writes the screenshot into the output folder; logs and notifies when that fails
    /// - Returns: Whether it was saved
    func save(_ screenshot: Screenshot) async -> Bool {
        do {
            let url = try await service.save(screenshot, settings: settings)
            logger.info("Screenshot saved: \(url.lastPathComponent)")
            return true
        } catch {
            logger.error("Screenshot save failed: \(error.localizedDescription)")
            notificationService.sendScreenshotFailedNotification(error: error)
            return false
        }
    }

    /// What a screenshot captures
    private struct Target {
        let filter: SCContentFilter
        /// The part of the filter's display to capture, for an area
        var sourceRect: CGRect?
        /// That part's place on screen (bottom-left origin), which the card opens next to
        var region: CGRect?
    }

    /// Checks permission, lets the user select (nil = cancelled), then captures
    private func capture(_ select: () async throws -> Target?) async {
        guard !isCapturing else { return }
        isCapturing = true
        onWillCapture?()
        var screenshot: Screenshot?
        defer {
            isCapturing = false
            onDidCapture?(screenshot)
        }

        do {
            try service.verifyPermission()
            guard let target = try await select() else {
                logger.info("Screenshot cancelled")
                return
            }
            var captured = try await service.capture(target.filter, sourceRect: target.sourceRect, settings: settings)
            captured.region = target.region
            logger.info("Screenshot captured: \(captured.image.width)×\(captured.image.height) px")
            screenshot = captured
        } catch {
            logger.error("Screenshot failed: \(error.localizedDescription)")
            notificationService.sendScreenshotFailedNotification(error: error)
        }
    }
}
