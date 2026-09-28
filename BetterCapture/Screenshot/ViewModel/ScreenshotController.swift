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

    /// Called with each captured screenshot; nothing is written until `save(_:)`
    @ObservationIgnored var onCaptured: (@MainActor (Screenshot) -> Void)?

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
            guard let selection = await areaSelectionOverlay.present() else { return nil }
            let display = try await service.display(for: selection.screen)
            let sourceRect = CaptureSizeCalculator.sourceRect(
                for: selection.screenRect,
                in: selection.screen.frame,
                scale: selection.screen.backingScaleFactor
            )
            return (SCContentFilter(display: display, excludingWindows: []), sourceRect)
        }
    }

    func captureWindow() async {
        await capture {
            guard let filter = await windowPicker.pick() else { return nil }
            return (filter, nil)
        }
    }

    func captureScreen() async {
        await capture {
            // ponytail: fixed wait for the popover's close animation, which only matters with Show
            // BetterCapture on (otherwise its windows are filtered out). Measure and tune, or wait on the window.
            try? await Task.sleep(for: .milliseconds(250))
            let mouse = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return nil }
            return (SCContentFilter(display: try await service.display(for: screen), excludingWindows: []), nil)
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

    /// Checks permission, lets the user select (nil = cancelled), then captures
    private func capture(_ select: () async throws -> (filter: SCContentFilter, sourceRect: CGRect?)?) async {
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }
        onWillCapture?()

        do {
            try service.verifyPermission()
            guard let target = try await select() else {
                logger.info("Screenshot cancelled")
                return
            }
            let screenshot = try await service.capture(target.filter, sourceRect: target.sourceRect, settings: settings)
            logger.info("Screenshot captured: \(screenshot.image.width)×\(screenshot.image.height) px")
            onCaptured?(screenshot)
        } catch {
            logger.error("Screenshot failed: \(error.localizedDescription)")
            notificationService.sendScreenshotFailedNotification(error: error)
        }
    }
}
