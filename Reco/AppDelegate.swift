//
//  AppDelegate.swift
//  Reco
//
//  Created by Joshua Sattler on 30.08.26.
//

import AppKit
import KeyboardShortcuts
import OSLog

/// Owns the recorder, registers the global keyboard shortcuts, and handles
/// `reco://` URLs.
///
/// None of this can live on the `MenuBarExtra` scene. SwiftUI only routes external
/// events such as URLs to window-presenting scenes, and the menu bar content is not built
/// until the user first opens the popover, so neither `onOpenURL` nor a `.task` there ever
/// runs at launch. `NSApplicationDelegate` is active from launch onwards, which is why the
/// recorder is owned here: it has to be reachable without the popover ever being opened.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let viewModel = RecorderViewModel()

    /// Shares the recorder's settings and notifications
    lazy var screenshots = ScreenshotController(settings: viewModel.settings, notificationService: viewModel.notificationService)

    /// Every control for a screenshot or a take, on screen under the status item
    private lazy var captureToolbar = CaptureToolbarController(viewModel: CaptureToolbarViewModel(recorder: viewModel, screenshots: screenshots))

    private lazy var editorWindows = EditorWindowManager(settings: viewModel.settings)
    lazy var quickAccess = QuickAccessController(
        save: { [screenshots] screenshot in await screenshots.save(screenshot) },
        background: { [settings = viewModel.settings] in settings.screenshotBackground }
    )
    private lazy var notchShelf = NotchShelfController(settings: viewModel.settings)

    /// Serves the tools coding agents record web pages with; a movie it renders opens in the editor.
    lazy var agentBridge = AgentBridgeServer(tools: AgentTools(settings: viewModel.settings) { [editorWindows] url in editorWindows.open(url) })

    /// Runs coding agents on a request typed into the Record with AI Agent panel.
    lazy var agentRecording = AgentRecordingViewModel(
        tools: agentBridge.tools,
        reportFailure: { [notifications = viewModel.notificationService] in notifications.sendAgentRecordingFailedNotification(reason: $0) },
        token: AgentBridgeServer.token()
    )

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerKeyboardShortcuts()
        // Made now so it follows selections and takes started before it is first shown
        _ = captureToolbar
        ColorPanelPlacement.start()
        notchShelf.start()
        agentBridge.start()
        viewModel.notificationService.editRecording = editorWindows.open
        viewModel.onRecordingFinished = editorWindows.open
        editorWindows.agentRecording = agentRecording
        editorWindows.libraryActions = LibraryViewModel.Actions(
            captureArea: { [screenshots] in Task { await screenshots.captureArea() } },
            captureWindow: { [screenshots] in Task { await screenshots.captureWindow() } },
            captureScreen: { [screenshots] in Task { await screenshots.captureScreen() } },
            recordArea: { [viewModel] in Task { await viewModel.presentAreaSelection() } },
            recordWindowOrDisplay: { [viewModel] in viewModel.presentPicker() },
            newWebRecording: { [weak self] in self?.showWebRecording() }
        )
        // The Web Recording window shows what an agent looks at and plans, as it does
        agentBridge.tools.onInspected = { [editorWindows] page in editorWindows.webRecordingViewModel?.showAgentInspection(page) }
        agentBridge.tools.onPlanned = { [editorWindows] script in editorWindows.webRecordingViewModel?.adoptAgentScript(script) }
        // When the chat's agent is done, its plan is rendered and opens in the editor
        agentRecording.onPlanStaged = { [editorWindows] in editorWindows.webRecordingViewModel?.render() }
        // The agent browses in the Web Recording window's live page, so the user sees it learn the site
        agentBridge.tools.browser = { [editorWindows] in editorWindows.webRecordingForAgent() }
        viewModel.notificationService.retryAgentRecording = { [agentRecording] in agentRecording.retry() }
        viewModel.notificationService.showAgentRecording = { [weak self] in self?.showAgentRecording() }

        // Hidden first so the last card, the capture toolbar and the notch shelf never land in the next
        // shot, even with Show Reco on. The card and the shelf come back when nothing was captured; the
        // bar doesn't, because it was only ever the way in: Esc on an area selection closes it and leaves
        // the screen as it was, rather than opening the bar again.
        screenshots.onWillCapture = { [quickAccess, captureToolbar, notchShelf] in
            quickAccess.hide()
            captureToolbar.hide(animated: false)
            notchShelf.hide()
        }
        screenshots.onDidCapture = { [quickAccess, notchShelf] screenshot, followUp in
            notchShelf.restore()
            if let screenshot, let followUp {
                quickAccess.restore()
                Task { await quickAccess.follow(followUp, with: screenshot) }
            } else if let screenshot {
                quickAccess.show(screenshot)
            } else {
                quickAccess.restore()
            }
        }
        hideNotchShelfWhileRecording()
    }

    /// The shelf's black shape sits over the notch, where a display recording would show it as a bar, even
    /// with Show Reco on. `state` turns `.recording` before the stream starts, so no frame catches it.
    private func hideNotchShelfWhileRecording() {
        withObservationTracking {
            _ = viewModel.state
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.viewModel.state == .idle {
                    self.notchShelf.restore()
                } else {
                    self.notchShelf.hide()
                }
                self.hideNotchShelfWhileRecording()
            }
        }
    }

    /// Shows the capture toolbar for a screenshot, or for a recording (`records`).
    func showCaptureToolbar(records: Bool) {
        captureToolbar.viewModel.open(records: records)
        captureToolbar.show()
    }

    /// Opens the last recording saved since launch in the editor.
    func editLastRecording() {
        guard let url = viewModel.lastRecordingURL else {
            logger.info("No recording to edit yet")
            return
        }
        editorWindows.open(url)
    }

    /// Shows the Library, Reco's main window: everything it made, and New.
    func showLibrary() {
        editorWindows.showLibrary()
    }

    /// Clicking Reco in the Dock, or opening it again, shows the Library when no window is open.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            showLibrary()
        }
        return true
    }

    /// Shows the Web Recording window with a blank script, to record a web page.
    func showWebRecording() {
        editorWindows.showNewWebRecording()
    }

    /// Shows the Web Recording window with its agent panel open, to have a coding agent record a web page.
    func showAgentRecording() {
        editorWindows.showAgentChat()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // The agent's command line would otherwise outlive the app
        agentRecording.cancel()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "reco" {
                handle(url)
            } else if url.pathExtension == StylePreset.fileExtension {
                editorWindows.importStyle(from: url)
            }
        }
    }

    // MARK: - Keyboard Shortcuts

    private func registerKeyboardShortcuts() {
        let recording: [(KeyboardShortcuts.Name, @MainActor (RecorderViewModel) async -> Void)] = [
            (.toggleRecording, { await $0.toggleRecording() }),
            (.pauseRecording, { $0.togglePause() }),
            (.restartRecording, { await $0.restartRecording() }),
            (.cancelRecording, { await $0.cancelRecording() }),
            (.selectContent, { $0.presentPicker() }),
            (.selectArea, { await $0.presentAreaSelection() })
        ]
        for (name, action) in recording {
            KeyboardShortcuts.onKeyUp(for: name) { [viewModel] in
                Task { @MainActor in
                    await action(viewModel)
                }
            }
        }

        KeyboardShortcuts.onKeyUp(for: .recordWithAgent) { [weak self] in
            Task { @MainActor in
                self?.showAgentRecording()
            }
        }

        // Like the menu's rows, only while nothing is recording, counting down or capturing
        for (name, records) in [(KeyboardShortcuts.Name.showScreenshotToolbar, false), (.showRecordingToolbar, true)] {
            KeyboardShortcuts.onKeyUp(for: name) { [weak self, viewModel, screenshots] in
                Task { @MainActor in
                    guard screenshots.canCapture(alongside: viewModel) else { return }
                    self?.showCaptureToolbar(records: records)
                }
            }
        }

        let captures: [(KeyboardShortcuts.Name, @MainActor (ScreenshotController) async -> Void)] = [
            (.captureArea, { await $0.captureArea() }),
            (.capturePreviousArea, { await $0.capturePreviousArea() }),
            (.captureWindow, { await $0.captureWindow() }),
            (.captureScreen, { await $0.captureScreen() })
        ]
        for (name, capture) in captures {
            KeyboardShortcuts.onKeyUp(for: name) { [viewModel, screenshots, logger] in
                Task { @MainActor in
                    guard screenshots.canCapture(alongside: viewModel) else {
                        logger.info("Ignored \(name.rawValue) shortcut: recording, counting down or capturing")
                        return
                    }
                    await capture(screenshots)
                }
            }
        }

        logger.info("Registered global keyboard shortcuts")
    }

    // MARK: - URL Scheme

    private func handle(_ url: URL) {
        logger.info("Handling URL: \(url.absoluteString)")

        switch url.host {
        case "toggle", "toggle-copy":
            let copyToClipboard = url.host == "toggle-copy"
            Task {
                if viewModel.isRecording {
                    await viewModel.stopRecording(copyToClipboard: copyToClipboard)
                } else {
                    // Starts right away when content is already selected, without the countdown so automation stays precise
                    await viewModel.toggleRecording(countdown: false)
                }
            }
        case "pause":
            viewModel.togglePause()
        case "cancel":
            Task { await viewModel.cancelRecording() }
        case "restart":
            Task { await viewModel.restartRecording(countdown: false) }
        case "capture-area", "capture-previous-area", "capture-window", "capture-screen":
            captureScreenshot(from: url)
        case "edit-last":
            editLastRecording()
        case "open-recordings":
            let settings = viewModel.settings
            let didStart = settings.startAccessingOutputDirectory()
            defer {
                if didStart {
                    settings.stopAccessingOutputDirectory()
                }
            }
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settings.outputDirectory.path)
        default:
            logger.warning("Unhandled URL host: \(url.host ?? "nil")")
        }
    }

    /// `reco://capture-area`, `capture-previous-area`, `capture-window` or `capture-screen`, with `?then=copy|save|pin` in place of the card.
    /// Ignored, like the shortcuts, while recording, counting down or capturing.
    private func captureScreenshot(from url: URL) {
        let followUp = ScreenshotFollowUp(url: url)
        if followUp == nil, url.query()?.contains("then=") == true {
            logger.warning("Unknown then in \(url.absoluteString); opening the card")
        }
        Task {
            guard screenshots.canCapture(alongside: viewModel) else {
                logger.info("Ignored \(url.absoluteString): recording, counting down or capturing")
                return
            }
            switch url.host {
            case "capture-area": await screenshots.captureArea(then: followUp)
            case "capture-previous-area": await screenshots.capturePreviousArea(then: followUp)
            case "capture-window": await screenshots.captureWindow(then: followUp)
            default: await screenshots.captureScreen(then: followUp)
            }
        }
    }
}
