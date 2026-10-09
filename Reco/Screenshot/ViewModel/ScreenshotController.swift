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

    /// Called as a screenshot ends, with nil when it was cancelled or failed, and what its `reco://` link asked for;
    /// nothing is written until `save(_:)`
    @ObservationIgnored var onDidCapture: (@MainActor (Screenshot?, ScreenshotFollowUp?) -> Void)?

    /// Whether a screenshot is being selected or captured. Not observed: the popover would dim its rows
    /// a frame before the screen is grabbed, and a shot of the popover would show them dimmed.
    @ObservationIgnored private(set) var isCapturing = false

    private let settings: SettingsStore
    private let notificationService: NotificationService
    private let service = ScreenshotService()
    private let areaSelectionOverlay = AreaSelectionOverlay()
    private let windowPicker = WindowPicker()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "ScreenshotController")

    /// History copies still being written, by file name, so Save can wait for one before deleting it
    private var historyWrites: [String: Task<Void, Never>] = [:]

    /// The last area captured since launch, in screen points (bottom-left origin), and its display
    private var previousArea: (rect: CGRect, displayID: CGDirectDisplayID)?

    /// The self-timer (`SettingsStore.screenshotTimer`)
    let timer: RecordingCountdown
    private let timerOverlay = CountdownOverlay()

    init(settings: SettingsStore, notificationService: NotificationService, timer: RecordingCountdown = RecordingCountdown()) {
        self.settings = settings
        self.notificationService = notificationService
        self.timer = timer
        let retention = settings.screenshotHistoryRetention
        Task { await ScreenshotHistory.prune(retention: retention) }
    }

    /// Screenshots wait for the recorder: none while it records, stops or counts down, and only one at a time
    static func canCapture(recorderState: RecorderViewModel.RecordingState, isCountingDown: Bool, isCapturing: Bool) -> Bool {
        recorderState == .idle && !isCountingDown && !isCapturing
    }

    func canCapture(alongside recorder: RecorderViewModel) -> Bool {
        Self.canCapture(recorderState: recorder.state, isCountingDown: recorder.countdown.isRunning, isCapturing: isCapturing || timer.isRunning)
    }

    /// Runs `capture` once the self-timer has counted down, its number on the screen under the pointer, or at once
    /// when it's off. Esc cancels, and nothing is captured. The timer is only on screen before the capture starts, so
    /// it's never in the shot.
    func afterSelfTimer(_ capture: @escaping @MainActor () async -> Void) async {
        let seconds = settings.screenshotTimer.rawValue
        guard seconds > 0 else {
            await capture()
            return
        }
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        timerOverlay.show(countdown: timer, center: screen.map { CGPoint(x: $0.frame.midX, y: $0.frame.midY) }) { [weak self] in
            self?.cancelSelfTimer()
        }
        await timer.start(seconds: seconds) { [weak self] in
            self?.timerOverlay.dismiss()
            await capture()
        }.value
    }

    func cancelSelfTimer() {
        timer.cancel()
        timerOverlay.dismiss()
    }

    /// Freezes every display first and cuts the area from that, so what the overlay would take away
    /// from the apps under it (hover states, tooltips, open menus) is still in the shot
    /// - Parameter leavingPopover: Started from the menu bar popover, which is closing and stays out of
    ///   the shot; from a shortcut, the popover is in it like everything else on screen
    /// - Parameter followUp: What a `reco://` link asked for in place of the card
    func captureArea(leavingPopover: Bool = false, then followUp: ScreenshotFollowUp? = nil) async {
        await capture(then: followUp) {
            let frozen = try await service.captureDisplays(leavingPopover: leavingPopover, settings: settings)
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
            previousArea = (selection.screenRect, displayID)
            return screenshot
        }
    }

    /// The last area captured, again, without selecting it; Capture Area when there is none yet. Live, not
    /// frozen: nothing covers the screen first.
    func capturePreviousArea(then followUp: ScreenshotFollowUp? = nil) async {
        guard let previousArea else {
            await captureArea(then: followUp)
            return
        }
        await capture(then: followUp) {
            guard let screen = NSScreen.screens.first(where: { $0.displayID == previousArea.displayID }) else {
                throw CaptureError.selectedDisplayDisconnected
            }
            let sourceRect = CaptureSizeCalculator.sourceRect(for: previousArea.rect, in: screen.frame, scale: screen.backingScaleFactor)
            let filter = try await service.screenFilter(for: screen, leavingPopover: false)
            var screenshot = try await service.capture(filter, sourceRect: sourceRect, settings: settings)
            screenshot.region = previousArea.rect
            return screenshot
        }
    }

    func captureWindow(then followUp: ScreenshotFollowUp? = nil) async {
        await capture(then: followUp) {
            guard let filter = await windowPicker.pick() else { return nil }
            return try await service.capture(filter, sourceRect: nil, settings: settings)
        }
    }

    func captureScreen(leavingPopover: Bool = false, then followUp: ScreenshotFollowUp? = nil) async {
        await capture(then: followUp) {
            let mouse = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return nil }
            let filter = try await service.screenFilter(for: screen, leavingPopover: leavingPopover)
            return try await service.capture(filter, sourceRect: nil, settings: settings)
        }
    }

    /// Writes the screenshot into `SettingsStore.screenshotDirectory`, which replaces its history copy;
    /// logs and notifies when that fails
    /// - Returns: Whether it was saved
    func save(_ screenshot: Screenshot) async -> Bool {
        do {
            let url = try await service.save(screenshot, in: settings.screenshotDirectory)
            logger.info("Screenshot saved: \(url.lastPathComponent)")
            // The history write may still be running: wait, or the copy would outlive the delete
            await historyWrites[screenshot.filename]?.value
            await ScreenshotHistory.remove(named: screenshot.filename)
            return true
        } catch {
            logger.error("Screenshot save failed: \(error.localizedDescription)")
            notificationService.sendScreenshotFailedNotification(error: error)
            return false
        }
    }

    /// Checks permission, then lets the user select and capture (nil = cancelled)
    private func capture(then followUp: ScreenshotFollowUp?, _ take: () async throws -> Screenshot?) async {
        guard !isCapturing else { return }
        isCapturing = true
        onWillCapture?()
        var screenshot: Screenshot?
        defer {
            isCapturing = false
            onDidCapture?(screenshot, followUp)
        }

        do {
            try service.verifyPermission()
            guard let captured = try await take() else {
                logger.info("Screenshot cancelled")
                return
            }
            logger.info("Screenshot captured: \(captured.image.width)×\(captured.image.height) px")
            screenshot = captured
            keepInHistory(captured)
        } catch {
            logger.error("Screenshot failed: \(error.localizedDescription)")
            notificationService.sendScreenshotFailedNotification(error: error)
        }
    }

    /// Writes a copy into the history in the background, so the card doesn't wait for it, then prunes
    private func keepInHistory(_ screenshot: Screenshot) {
        let retention = settings.screenshotHistoryRetention
        guard retention != .off else { return }
        let name = screenshot.filename
        historyWrites[name] = Task {
            do {
                try await ScreenshotService.write(screenshot, to: ScreenshotHistory.directory.appending(path: name))
                await ScreenshotHistory.prune(retention: retention)
            } catch {
                logger.error("Screenshot history write failed: \(error.localizedDescription)")
            }
            historyWrites[name] = nil
        }
    }
}
