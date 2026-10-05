//
//  CaptureToolbarViewModel.swift
//  Reco
//

import Foundation
import ScreenCaptureKit

/// The capture toolbar's mode and intents: screenshots go to the screenshot controller, recordings to
/// the recorder. Reports up through `onHide` so the controller can take the panel away.
@MainActor
@Observable
final class CaptureToolbarViewModel {

    let recorder: RecorderViewModel
    let screenshots: ScreenshotController

    private(set) var mode: CaptureToolbarMode = .initial(records: true)

    /// Takes the toolbar away; `animated` is false before a screenshot, so it is gone from the shot
    @ObservationIgnored var onHide: ((_ animated: Bool) -> Void)?

    /// The display the bar is on, which Record Screen records
    @ObservationIgnored var currentDisplayID: (() -> CGDirectDisplayID?)?

    /// Set while a selection Record asked for is being made: the take starts as soon as it is chosen
    @ObservationIgnored private var startsOnSelection = false

    /// The windows or displays Record Window and Record Screen choose from, above the bar
    let sources = CaptureSourcePicker()

    init(recorder: RecorderViewModel, screenshots: ScreenshotController) {
        self.recorder = recorder
        self.screenshots = screenshots
        // The choice reaches `selectionDidChange()` through the recorder, which starts the take
        sources.onPick = { [recorder] filter in Task { await recorder.selectContent(filter) } }
        sources.onCancel = { [weak self] in self?.startsOnSelection = false }
    }

    /// Whether the action can run now: screenshots wait for the recorder, recordings for idle, and while
    /// the area is being chosen Record waits for one to be drawn
    var canPerformAction: Bool {
        guard mode.records else { return screenshots.canCapture(alongside: recorder) }
        if areaSelection.isPresented { return areaSelection.canConfirm }
        return recorder.state == .idle
    }

    /// The recording area selection, which Record confirms while it is up (the controller raises the bar
    /// above it so it stays clickable)
    var areaSelection: AreaSelectionOverlay { recorder.areaSelectionOverlay }

    // MARK: - Intents

    /// Shows the screenshot toolbar or the recording one, always on its area mode
    func open(records: Bool) {
        select(.initial(records: records))
    }

    /// Switches mode. A selection made for another mode is dropped, so Record never starts something
    /// the toolbar doesn't show.
    func select(_ newMode: CaptureToolbarMode) {
        guard newMode != mode else { return }
        sources.cancel()
        areaSelection.cancel()
        mode = newMode
        if recorder.hasContentSelected {
            Task { await recorder.resetSelection() }
        }
    }

    /// A mode was chosen on the bar: switch to it and start choosing what to record, so Record isn't a
    /// second click on the way to the picker. Screenshot modes and Record Screen, which have nothing to
    /// choose, only switch; their action commits.
    func pick(_ newMode: CaptureToolbarMode) async {
        select(newMode)
        guard newMode.records, newMode != .recordScreen, !recorder.hasContentSelected else { return }
        await chooseSource(for: newMode)
    }

    /// Takes the screenshot, or starts the recording: at once when its content is chosen, otherwise
    /// once it is.
    func performAction() async {
        guard canPerformAction else { return }
        // The area is being chosen: Record takes the one drawn, and the take starts from it
        if areaSelection.isPresented {
            areaSelection.confirm()
            return
        }
        // The picker is up: Record (and Return) takes the highlighted window
        if sources.isOpen {
            sources.pickHighlighted()
            return
        }
        switch mode {
        case .captureScreen:
            onHide?(false)
            await screenshots.captureScreen()
        case .captureWindow:
            onHide?(false)
            await screenshots.captureWindow()
        case .captureArea:
            onHide?(false)
            await screenshots.captureArea()
        case .recordScreen, .recordWindow, .recordArea:
            if recorder.hasContentSelected {
                await recorder.startRecordingWithCountdown()
                return
            }
            await chooseSource(for: mode)
        }
    }

    /// Opens the mode's own way of choosing what to record: Reco's picker for a window, the area overlay to
    /// draw on, and for the screen no choice at all, the one the bar is on. A choice then starts the take,
    /// through `selectionDidChange()`.
    private func chooseSource(for mode: CaptureToolbarMode) async {
        startsOnSelection = true
        switch mode {
        case .recordScreen:
            sources.pickDisplay(currentDisplayID?())
        case .recordWindow:
            sources.open(.window)
        default:
            // The toolbar's Record confirms it, so the selection needs no buttons of its own
            await recorder.presentAreaSelection(showsActions: false)
            // Chosen or cancelled by now
            startsOnSelection = false
        }
    }

    // MARK: - Options

    var settings: SettingsStore { recorder.settings }

    /// Turning the microphone or the camera on asks for its permission then, not when the take starts
    func toggleMicrophone() {
        settings.captureMicrophone.toggle()
        guard settings.captureMicrophone else { return }
        Task { await recorder.permissionService.requestMicrophonePermission() }
    }

    func toggleCamera() {
        settings.presenterOverlayEnabled.toggle()
        guard settings.presenterOverlayEnabled else { return }
        Task { await recorder.permissionService.requestCameraPermission() }
    }

    func toggleSystemAudio() {
        settings.captureSystemAudio.toggle()
    }

    /// Cancels a countdown, drops the selection and takes the toolbar away
    func close() async {
        sources.cancel()
        areaSelection.cancel()
        recorder.cancelCountdown()
        await recorder.resetSelection()
        onHide?(true)
    }

    /// What Esc does: the innermost thing open first, so a picker or a half-drawn area goes on its own
    /// and the toolbar only with the next press. The close control always closes everything.
    func cancel() async {
        if areaSelection.isPresented {
            areaSelection.cancel()
            return
        }
        if sources.isOpen {
            sources.cancel()
            return
        }
        await close()
    }

    /// Follows a selection made here or elsewhere: shows it as the mode, and starts the take Record asked for
    /// Synchronous: area selection reports from inside `presentAreaSelection()`, before `performAction()`
    /// clears `startsOnSelection`.
    func selectionDidChange() {
        guard let filter = recorder.selectedContentFilter else {
            startsOnSelection = false
            return
        }
        mode = .recording(isArea: recorder.isAreaSelection, isDisplay: CaptureFilterStyle(filter) == .display)
        if startsOnSelection {
            startsOnSelection = false
            Task { await recorder.startRecordingWithCountdown() }
        }
    }
}
