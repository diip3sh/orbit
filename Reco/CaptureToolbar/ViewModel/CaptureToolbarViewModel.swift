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

    private(set) var mode: CaptureToolbarMode {
        didSet { defaults.set(mode.rawValue, forKey: CaptureToolbarMode.storageKey(records: mode.records)) }
    }

    /// Takes the toolbar away; `animated` is false before a screenshot, so it is gone from the shot
    @ObservationIgnored var onHide: ((_ animated: Bool) -> Void)?

    /// Set while a selection Record asked for is being made: the take starts as soon as it is chosen
    @ObservationIgnored private var startsOnSelection = false

    @ObservationIgnored private let defaults: UserDefaults

    /// The windows or displays Record Window and Record Screen choose from, above the bar
    let sources = CaptureSourcePicker()

    init(recorder: RecorderViewModel, screenshots: ScreenshotController, defaults: UserDefaults = .standard) {
        self.recorder = recorder
        self.screenshots = screenshots
        self.defaults = defaults
        mode = Self.rememberedMode(records: true, in: defaults)
        // The choice reaches `selectionDidChange()` through the recorder, which starts the take
        sources.onPick = { [recorder] filter in Task { await recorder.selectContent(filter) } }
        sources.onCancel = { [weak self] in self?.startsOnSelection = false }
    }

    /// Whether the action can run now: screenshots wait for the recorder, recordings for idle
    var canPerformAction: Bool {
        mode.records ? recorder.state == .idle : screenshots.canCapture(alongside: recorder)
    }

    private static func rememberedMode(records: Bool, in defaults: UserDefaults) -> CaptureToolbarMode {
        defaults.string(forKey: CaptureToolbarMode.storageKey(records: records))
            .flatMap(CaptureToolbarMode.init(rawValue:))
            .flatMap { $0.records == records ? $0 : nil } ?? .initial(records: records)
    }

    // MARK: - Intents

    /// Shows the screenshot toolbar or the recording one, on the mode each was last left in
    func open(records: Bool) {
        guard mode.records != records else { return }
        select(Self.rememberedMode(records: records, in: defaults))
    }

    /// Switches mode. A selection made for another mode is dropped, so Record never starts something
    /// the toolbar doesn't show.
    func select(_ newMode: CaptureToolbarMode) {
        guard newMode != mode else { return }
        sources.cancel()
        mode = newMode
        if recorder.hasContentSelected {
            Task { await recorder.resetSelection() }
        }
    }

    /// Takes the screenshot, or starts the recording: at once when its content is chosen, otherwise
    /// once it is.
    func performAction() async {
        guard canPerformAction else { return }
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
            startsOnSelection = true
            switch mode {
            case .recordScreen:
                sources.open(.display)
            case .recordWindow:
                sources.open(.window)
            default:
                await recorder.presentAreaSelection()
                // Chosen or cancelled by now
                startsOnSelection = false
            }
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
        recorder.cancelCountdown()
        await recorder.resetSelection()
        onHide?(true)
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
