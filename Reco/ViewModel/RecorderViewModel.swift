//
//  RecorderViewModel.swift
//  Reco
//
//  Created by Joshua Sattler on 29.01.26.
//

import Foundation
@preconcurrency import ScreenCaptureKit
import AppKit
import OSLog

/// The main view model managing recording state and coordination between services
@MainActor
@Observable
final class RecorderViewModel {

    // MARK: - Recording State

    enum RecordingState {
        case idle
        case recording
        case stopping
    }

    // MARK: - Published Properties

    private(set) var state: RecordingState = .idle
    private(set) var recordingDuration: TimeInterval = 0

    /// Whether the recording is paused. `isRecording` stays true while paused.
    private(set) var isPaused = false
    private(set) var lastError: Error?
    private(set) var selectedContentFilter: SCContentFilter?

    /// The last recording saved with video since launch, for Edit Last Recording.
    private(set) var lastRecordingURL: URL?

    /// The source rectangle for area selection (in display points, top-left origin)
    private(set) var selectedSourceRect: CGRect?

    /// The selected area in screen coordinates (bottom-left origin), used for the border frame overlay
    private var selectedScreenRect: CGRect?

    /// The screen on which the area selection was made
    private var selectedScreen: NSScreen?

    /// Whether the current selection is an area selection (as opposed to a picker selection)
    var isAreaSelection: Bool {
        selectedSourceRect != nil
    }

    var isRecording: Bool {
        state == .recording
    }

    var canStartRecording: Bool {
        selectedContentFilter != nil && state == .idle
    }

    var hasContentSelected: Bool {
        selectedContentFilter != nil
    }

    var formattedDuration: String {
        let hours = Int(recordingDuration) / 3600
        let minutes = (Int(recordingDuration) % 3600) / 60
        let seconds = Int(recordingDuration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Whether Presenter Overlay is currently active (camera composited into stream)
    private(set) var isPresenterOverlayActive = false

    // MARK: - Dependencies

    let settings: SettingsStore
    let audioDeviceService: AudioDeviceService
    let cameraDeviceService: CameraDeviceService
    let previewService: PreviewService
    let notificationService: NotificationService
    let permissionService: PermissionService
    private let captureEngine: CaptureEngine
    private let assetWriter: AssetWriter
    private let cameraSession = CameraSession()
    private let inputTelemetry = InputTelemetryRecorder()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "RecorderViewModel")

    // MARK: - Private Properties

    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var videoSize: CGSize = .zero
    private let areaSelectionOverlay = AreaSelectionOverlay()
    private let selectionBorderFrame = SelectionBorderFrame()
    private let recordingOverlay = RecordingOverlayCoordinator()

    /// The countdown before a user-started recording; read by the menu bar UI
    let countdown = RecordingCountdown()
    private let countdownOverlay = CountdownOverlay()

    // MARK: - Initialization

    init() {
        self.settings = SettingsStore()
        self.audioDeviceService = AudioDeviceService()
        self.cameraDeviceService = CameraDeviceService()
        self.previewService = PreviewService()
        self.notificationService = NotificationService(settings: settings)
        self.permissionService = PermissionService()
        self.captureEngine = CaptureEngine()
        self.assetWriter = AssetWriter()

        captureEngine.delegate = self
        captureEngine.sampleBufferDelegate = assetWriter
        previewService.delegate = self
    }

    // MARK: - Permission Methods

    /// Requests required permissions on app launch
    /// Only requests microphone permission if microphone capture is enabled
    func requestPermissionsOnLaunch() async {
        await permissionService.requestPermissions(
            includeMicrophone: settings.captureMicrophone,
            includeCamera: settings.presenterOverlayEnabled
        )
    }

    /// Refreshes the current permission states
    func refreshPermissions() {
        permissionService.updatePermissionStates()
    }

    // MARK: - Public Methods

    /// Toggles the recording state. If no content is selected, triggers the appropriate
    /// selection flow based on the user's content selection mode preference.
    /// - Parameter countdown: Whether a start waits for the countdown from Settings. `reco://`
    ///   URLs pass `false` so automation starts instantly; that also cancels a countdown already running.
    func toggleRecording(countdown useCountdown: Bool = true) async {
        if isRecording {
            await stopRecording()
        } else if hasContentSelected {
            if useCountdown {
                await startRecordingWithCountdown()
            } else {
                cancelCountdown()
                await startRecording()
            }
        } else {
            // No content selected — trigger selection based on the user's preferred mode
            switch ContentSelectionMode.current {
            case .pickContent:
                presentPicker()
            case .selectArea:
                await presentAreaSelection()
            }
        }
    }

    /// Presents the system content sharing picker
    func presentPicker() {
        captureEngine.presentPicker()
    }

    /// Presents the area selection overlay on the display under the cursor
    func presentAreaSelection() async {
        // Dismiss any existing border frame so it doesn't overlap the selection overlay
        selectionBorderFrame.dismiss()

        guard let result = await areaSelectionOverlay.present() else {
            logger.info("Area selection cancelled")
            return
        }

        // Show the border frame immediately so the user sees the selection outline
        selectionBorderFrame.show(screenRect: result.screenRect)

        // Find the corresponding SCDisplay for the selected screen
        do {
            let content = try await SCShareableContent.current
            let screenNumber = result.screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID

            guard let display = content.displays.first(where: { $0.displayID == screenNumber }) else {
                logger.error("Could not find SCDisplay for selected screen")
                return
            }

            // Create a content filter for the full display
            let filter = SCContentFilter(display: display, excludingWindows: [])

            // Convert screen rect (NSScreen coordinates, bottom-left origin) to
            // sourceRect (display coordinates, top-left origin), snapped to even pixel counts
            let sourceRect = CaptureSizeCalculator.sourceRect(
                for: result.screenRect,
                in: result.screen.frame,
                scale: result.screen.backingScaleFactor
            )

            // Clear any existing picker selection (mutually exclusive)
            captureEngine.clearSelection()

            // Store the area selection and set the filter on the capture engine
            selectedSourceRect = sourceRect
            selectedScreenRect = result.screenRect
            selectedScreen = result.screen
            selectedContentFilter = filter
            try await captureEngine.updateFilter(filter)

            logger.info("Area selected: sourceRect=\(sourceRect.debugDescription), display=\(display.displayID)")

            // Update preview with the display filter and source rect
            await previewService.setContentFilter(filter, sourceRect: sourceRect)

            // Show the recording overlay on the screen where the area was selected
            recordingOverlay.show(viewModel: self, screen: selectedScreen)

        } catch {
            selectionBorderFrame.dismiss()
            logger.error("Failed to get shareable content for area selection: \(error.localizedDescription)")
        }
    }

    /// Starts a new recording session
    func startRecording() async {
        guard canStartRecording else {
            logger.warning("Cannot start recording: no content selected or already recording")
            return
        }

        // Dismiss the recording overlay if it's still visible
        recordingOverlay.dismiss()

        do {
            state = .recording
            lastError = nil

            logger.info("Starting recording sequence...")

            // Stop any active live preview before starting recording
            logger.info("Stopping any active live preview...")
            await previewService.stopPreview()
            logger.info("Live preview stopped")

            // Determine video size from filter
            if let filter = selectedContentFilter {
                videoSize = await getContentSize(from: filter)
            }
            logger.info("Video size: \(self.videoSize.width)x\(self.videoSize.height)")

            // Access security-scoped output directory before writing
            _ = settings.startAccessingOutputDirectory()

            // Setup asset writer
            let outputURL = settings.generateOutputURL()
            try assetWriter.setup(url: outputURL, settings: settings, videoSize: videoSize)
            try assetWriter.startWriting()
            logger.info("AssetWriter ready")

            // Start camera for Presenter Overlay before capture so the system detects it.
            // The camera has to be running before the SCStream starts, which is earlier than
            // the engine's own permission checks, so camera access is verified here instead.
            if settings.presenterOverlayEnabled {
                guard await permissionService.requestCameraPermission() else {
                    throw CaptureError.cameraPermissionDenied
                }

                await cameraSession.start(deviceID: settings.selectedCameraID)
            }

            // Start capture with the calculated video size
            logger.info("Starting capture engine...")
            try await captureEngine.startCapture(with: settings, videoSize: videoSize, sourceRect: selectedSourceRect)

            // Started after the last throwing step, so the catch below has nothing to undo
            startInputTelemetryIfNeeded()

            // Re-show the area selection border now that capture has started
            if isAreaSelection, let screenRect = selectedScreenRect {
                selectionBorderFrame.show(screenRect: screenRect)
            }

            // Start timer
            startTimer()

            logger.info("Recording started")

        } catch {
            state = .idle
            lastError = error
            cameraSession.stop()
            selectionBorderFrame.dismiss()

            // The writer may already be set up and holding an empty output file. Cancel it
            // before releasing the output directory, since that is where the file lives.
            assetWriter.cancel()
            settings.stopAccessingOutputDirectory()

            // lastError has no UI representation, so every start failure has to be surfaced
            // as a notification - otherwise the record button silently does nothing.
            notificationService.sendRecordingStartFailedNotification(error: error)

            // The selection points at a display that is gone, so drop it. The next recording
            // attempt then opens the picker instead of failing the same way again.
            if error as? CaptureError == .selectedDisplayDisconnected {
                await resetSelection()
            }

            logger.error("Failed to start recording: \(error.localizedDescription)")
        }
    }

    /// Starts input telemetry recording, if enabled and a content filter is selected.
    private func startInputTelemetryIfNeeded() {
        guard settings.recordInputTelemetry, let filter = selectedContentFilter else { return }
        inputTelemetry.start(
            filter: filter,
            sourceRect: selectedSourceRect,
            videoSize: videoSize,
            cursorInVideo: settings.capturesCursor,
            frameRate: settings.frameRate.effectiveFrameRate
        )
    }

    /// Stops the current recording session
    func stopRecording(copyToClipboard: Bool = false) async {
        guard isRecording else { return }

        state = .stopping
        stopTimer()
        isPaused = false
        selectionBorderFrame.dismiss()
        inputTelemetry.stop()

        do {
            // Stop capture and camera session
            try await captureEngine.stopCapture()
            cameraSession.stop()
            isPresenterOverlayActive = false

            // Finalize file. The session start and pauses are read first because finishing resets them.
            let sessionStart = assetWriter.sessionStartTime
            let pauses = assetWriter.pauseIntervals
            let (outputURL, videoFrameCount) = try await assetWriter.finishWriting()

            state = .idle
            recordingDuration = 0

            logger.info("Recording stopped and saved to: \(outputURL.lastPathComponent)")

            // Written while the output directory's security scope is still held
            var cursorLeftToEditor = false
            if videoFrameCount > 0 {
                cursorLeftToEditor = await inputTelemetry.writeSidecar(for: outputURL, sessionStart: sessionStart, pauses: pauses, geometry: captureEngine.frameGeometry.track)
            }

            // Brief delay to ensure screen sharing mode has fully stopped before sending notification
            try? await Task.sleep(for: .milliseconds(100))

            reportSaved(outputURL, videoFrameCount: videoFrameCount, cursorLeftToEditor: cursorLeftToEditor)

            if copyToClipboard {
                copyFileToClipboard(outputURL)
            }

            settings.stopAccessingOutputDirectory()

        } catch {
            state = .idle
            lastError = error
            assetWriter.cancel()
            settings.stopAccessingOutputDirectory()
            notificationService.sendRecordingFailedNotification(error: error)
            logger.error("Failed to stop recording: \(error.localizedDescription)")
        }
    }

    /// Resets the capture selection, removing the border frame and clearing state
    ///
    /// Covers both area and picker selections, so the capture engine's filter is cleared
    /// alongside the view model's - otherwise the engine keeps a filter the UI no longer shows.
    func resetSelection() async {
        selectedSourceRect = nil
        selectedScreenRect = nil
        selectedScreen = nil
        selectedContentFilter = nil
        captureEngine.clearSelection()
        selectionBorderFrame.dismiss()
        recordingOverlay.dismiss()
        await previewService.stopPreview()
        previewService.clearPreview()
    }

    /// Starts the live preview stream (call when menu bar window opens)
    func startPreview() async {
        guard !isRecording else { return }
        await previewService.startPreview()
    }

    /// Stops the live preview stream (call when menu bar window closes)
    func stopPreview() async {
        await previewService.stopPreview()
    }

    // MARK: - Timer Management

    private func startTimer() {
        recordingStartTime = Date()
        recordingDuration = 0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                // Frozen while paused; togglePause() shifts the start time on resume
                guard let self, !self.isPaused, let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
    }

    // MARK: - Helper Methods

    private func copyFileToClipboard(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])
    }

    private func getContentSize(from filter: SCContentFilter) async -> CGSize {
        // Apply scale if Capture Native Resolution setting is enabled
        let applyScale: Bool = settings.captureNativeResolution

        // If area selection is active, use the source rect dimensions.
        // The sourceRect is already snapped to even pixel counts in presentAreaSelection().
        if let sourceRect = selectedSourceRect {
            return CaptureSizeCalculator.videoSize(
                contentRect: sourceRect,
                scale: CGFloat(filter.pointPixelScale),
                useNativeResolution: applyScale
            )
        }

        // Get the content rect from the filter
        let rect = filter.contentRect

        if rect.width > 0 && rect.height > 0 {
            return CaptureSizeCalculator.videoSize(
                contentRect: rect,
                scale: filter.captureScale,
                useNativeResolution: applyScale
            )
        }

        // Fallback to main screen size
        if let screen = NSScreen.main {
            return CGSize(
                width: applyScale ? screen.frame.width * screen.backingScaleFactor : screen.frame.width,
                height: applyScale ? screen.frame.height * screen.backingScaleFactor : screen.frame.height
            )
        }

        return CGSize(width: 1920, height: 1080)
    }
}

// MARK: - Saved Recordings

extension RecorderViewModel {

    /// Notifies the user of a saved recording, and keeps it for Edit Last Recording when it has video.
    ///
    /// The file is kept either way - an audio-only recording is still worth more than a deleted
    /// one - but the user has to be told about it.
    private func reportSaved(_ outputURL: URL, videoFrameCount: Int, cursorLeftToEditor: Bool) {
        if videoFrameCount == 0 {
            logger.error("Recording contains no video frames: \(outputURL.lastPathComponent)")
            notificationService.sendRecordingMissingVideoNotification(fileURL: outputURL)
        } else {
            lastRecordingURL = outputURL
            notificationService.sendRecordingSavedNotification(fileURL: outputURL, opensEditor: cursorLeftToEditor)
        }
    }
}

// MARK: - Pausing

extension RecorderViewModel {

    /// Pauses or resumes the recording.
    ///
    /// The capture keeps running while paused, so resuming is instant; the writer drops everything
    /// captured in between and the paused time is cut from the file. Does nothing until capture has started.
    func togglePause() {
        guard isRecording, let recordingStartTime else { return }

        if isPaused {
            assetWriter.resume()
            // Carry the timer on from where it was frozen
            self.recordingStartTime = Date().addingTimeInterval(-recordingDuration)
        } else {
            assetWriter.pause()
            recordingDuration = Date().timeIntervalSince(recordingStartTime)
        }

        isPaused.toggle()
        logger.info("Recording \(self.isPaused ? "paused" : "resumed")")
    }
}

// MARK: - Cancelling

extension RecorderViewModel {

    /// Stops the recording and throws it away: nothing is left in the output folder.
    func cancelRecording() async {
        guard isRecording else { return }

        state = .stopping
        stopTimer()
        isPaused = false
        selectionBorderFrame.dismiss()
        inputTelemetry.stop()
        // The file is removed whether or not the stream stops cleanly
        try? await captureEngine.stopCapture()
        cameraSession.stop()
        isPresenterOverlayActive = false
        assetWriter.cancel()
        settings.stopAccessingOutputDirectory()

        state = .idle
        recordingDuration = 0
        logger.info("Recording cancelled")
    }

    /// Throws the recording away and starts again with the same selection.
    /// - Parameter countdown: Whether the new start waits for the countdown from Settings.
    func restartRecording(countdown useCountdown: Bool = true) async {
        guard isRecording else { return }
        await cancelRecording()
        if useCountdown {
            await startRecordingWithCountdown()
        } else {
            await startRecording()
        }
    }
}

// MARK: - Countdown

extension RecorderViewModel {

    /// Starts recording after the countdown from Settings, or cancels the countdown if one is running.
    ///
    /// Every user-initiated start goes through here. The normal `startRecording()` runs once the
    /// countdown ends; with the countdown off, or nothing to record, it is called straight away.
    func startRecordingWithCountdown() async {
        if countdown.isRunning {
            cancelCountdown()
            return
        }

        let seconds = settings.countdownDuration.rawValue
        guard seconds > 0, canStartRecording else {
            await startRecording()
            return
        }

        recordingOverlay.dismiss()
        countdownOverlay.show(countdown: countdown, center: countdownCenter) { [weak self] in
            self?.cancelCountdown()
        }
        countdown.start(seconds: seconds) { [weak self] in
            guard let self else { return }
            // Ordered out before capture starts, so the number never appears in the recording
            countdownOverlay.dismiss()
            await startRecording()
        }
        logger.info("Countdown started: \(seconds)s")
    }

    /// Cancels a running countdown. Nothing is recorded.
    func cancelCountdown() {
        guard countdown.isRunning else { return }
        countdown.cancel()
        countdownOverlay.dismiss()
        logger.info("Countdown cancelled")
    }

    /// The centre of what is about to be recorded, in screen coordinates (bottom-left origin)
    private var countdownCenter: CGPoint? {
        if let selectedScreenRect {
            return CGPoint(x: selectedScreenRect.midX, y: selectedScreenRect.midY)
        }

        guard let filter = selectedContentFilter,
              let frame = filter.includedWindows.first?.frame ?? filter.includedDisplays.first?.frame,
              let primaryScreen = NSScreen.screens.first else {
            return nil
        }

        // SCWindow and SCDisplay frames use CoreGraphics coordinates: top-left origin of the primary display
        return CGPoint(x: frame.midX, y: primaryScreen.frame.height - frame.midY)
    }
}

// MARK: - CaptureEngineDelegate

extension RecorderViewModel: CaptureEngineDelegate {

    func captureEngine(_ engine: CaptureEngine, didUpdateFilter filter: SCContentFilter) {
        // Clear any area selection (picker and area selections are mutually exclusive)
        selectedSourceRect = nil
        selectedScreenRect = nil
        selectedScreen = nil
        selectionBorderFrame.dismiss()

        selectedContentFilter = filter
        logger.info("Content filter updated")

        // Capture a static thumbnail for the preview
        Task {
            await previewService.setContentFilter(filter)
        }

        // Show the recording overlay. For picker selections there is no stored screen
        // (selectedScreen is nil), so the overlay positions itself below the status item.
        recordingOverlay.show(viewModel: self, screen: selectedScreen)
    }

    func captureEngine(_ engine: CaptureEngine, didStopWithError error: Error?) {
        // Check if user clicked "Stop Sharing" in the menu bar
        let isUserStopped = (error as? SCStreamError)?.code == .userStopped

        if let error, !isUserStopped {
            lastError = error
            logger.error("Capture stopped with error: \(error.localizedDescription)")
        }

        // Clean up if we were recording
        if isRecording {
            if isUserStopped {
                // User clicked "Stop Sharing" - gracefully save the recording
                logger.info("User stopped sharing via system UI, saving recording...")
                Task {
                    await stopRecording()
                }
            } else {
                // Stream error during recording - try to save what we have
                logger.warning("Stream stopped unexpectedly, attempting to save recording...")
                Task {
                    await stopRecording()
                }
            }
        }
    }

    func captureEngine(_ engine: CaptureEngine, systemAudioDidFailWith error: Error?) {
        // The video recording keeps running; only system audio is missing from the output
        logger.error("System audio capture failed: \(error?.localizedDescription ?? "unknown error")")
        notificationService.sendSystemAudioFailedNotification(error: error)
    }

    func captureEngine(_ engine: CaptureEngine, presenterOverlayDidChange isActive: Bool) {
        isPresenterOverlayActive = isActive
        logger.info("Presenter Overlay \(isActive ? "activated" : "deactivated")")
    }

    func captureEngineDidCancelPicker(_ engine: CaptureEngine) {
        logger.info("Picker was cancelled, clearing selection and preview")

        // Clear the selected content filter
        selectedContentFilter = nil

        // Dismiss the overlay if it was shown after a previous selection
        recordingOverlay.dismiss()

        // Stop and clear the preview
        Task {
            await previewService.stopPreview()
            previewService.clearPreview()
        }
    }
}

// MARK: - PreviewServiceDelegate

extension RecorderViewModel: PreviewServiceDelegate {

    func previewServiceDidStopByUser(_ service: PreviewService) {
        logger.info("User stopped sharing via system UI, clearing selection")

        // Clear the selection
        selectedContentFilter = nil

        // Clear the content filter in capture engine and deactivate picker
        captureEngine.clearSelection()
        captureEngine.deactivatePicker()
    }
}
