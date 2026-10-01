//
//  ScreenshotController.swift
//  Reco
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
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "ScreenshotController")

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

    /// Freezes every display first and cuts the area from that, so what the overlay would take away
    /// from the apps under it (hover states, tooltips, open menus) is still in the shot
    func captureArea() async {
        await capture {
            let frozen = try await service.captureDisplays(settings: settings)
            guard let selection = await areaSelectionOverlay.present(confirmsOnRelease: true, frozen: frozen.mapValues(\.image)) else {
                return nil
            }
            guard let displayID = selection.screen.displayID, let display = frozen[displayID] else {
                throw CaptureError.selectedDisplayDisconnected
            }
            let sourceRect = CaptureSizeCalculator.sourceRect(
                for: selection.screenRect,
                in: selection.screen.frame,
                scale: selection.screen.backingScaleFactor
            )
            var screenshot = display.cropped(to: sourceRect)
            screenshot?.region = selection.screenRect
            return screenshot
        }
    }

    func captureWindow() async {
        await capture {
            guard let filter = await windowPicker.pick() else { return nil }
            return try await service.capture(filter, sourceRect: nil, settings: settings)
        }
    }

    func captureScreen() async {
        await capture {
            // ponytail: fixed wait for the popover's close animation, which only matters with Show
            // Reco on (otherwise its windows are filtered out). Measure and tune, or wait on the window.
            try? await Task.sleep(for: .milliseconds(250))
            let mouse = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return nil }
            let filter = SCContentFilter(display: try await service.display(for: screen), excludingWindows: [])
            return try await service.capture(filter, sourceRect: nil, settings: settings)
        }
    }

    /// Writes the screenshot into `~/Pictures/Reco`; logs and notifies when that fails
    /// - Returns: Whether it was saved
    func save(_ screenshot: Screenshot) async -> Bool {
        do {
            let url = try await service.save(screenshot)
            logger.info("Screenshot saved: \(url.lastPathComponent)")
            return true
        } catch {
            logger.error("Screenshot save failed: \(error.localizedDescription)")
            notificationService.sendScreenshotFailedNotification(error: error)
            return false
        }
    }

    /// Checks permission, then lets the user select and capture (nil = cancelled)
    private func capture(_ take: () async throws -> Screenshot?) async {
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
            guard let captured = try await take() else {
                logger.info("Screenshot cancelled")
                return
            }
            logger.info("Screenshot captured: \(captured.image.width)×\(captured.image.height) px")
            screenshot = captured
        } catch {
            logger.error("Screenshot failed: \(error.localizedDescription)")
            notificationService.sendScreenshotFailedNotification(error: error)
        }
    }
}
