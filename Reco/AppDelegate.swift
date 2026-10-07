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

    private lazy var editorWindows: EditorWindowManager = EditorWindowManager(settings: viewModel.settings, agentRecording: agentRecording)
    private lazy var quickAccess = QuickAccessController { [screenshots] screenshot in await screenshots.save(screenshot) }

    /// Serves the tools coding agents record web pages with. A movie it renders for an agent the user
    /// runs opens in the editor right away; one for a run of Reco's own opens when the run ends, with
    /// its conversation.
    lazy var agentBridge: AgentBridgeServer = AgentBridgeServer(tools: AgentTools(settings: viewModel.settings) { [weak self] url in
        guard let self, !agentRecording.isRunning else { return }
        editorWindows.open(url)
    })

    /// Runs coding agents on a request typed into the Record with AI Agent panel.
    lazy var agentRecording: AgentRecordingViewModel = AgentRecordingViewModel(
        tools: agentBridge.tools,
        reportFailure: { [notifications = viewModel.notificationService] in notifications.sendAgentRecordingFailedNotification(reason: $0) },
        token: AgentBridgeServer.token()
    )

    private lazy var agentRecordingPanel = AgentRecordingPanelController(viewModel: agentRecording)

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerKeyboardShortcuts()
        agentBridge.start()
        viewModel.notificationService.editRecording = { [editorWindows] (url: URL) in editorWindows.open(url) }
        viewModel.notificationService.retryAgentRecording = { [agentRecording] in agentRecording.retry() }
        agentRecording.onRecorded = { [editorWindows] in editorWindows.open($0) }
        viewModel.notificationService.showAgentRecording = { [weak self] in self?.showAgentRecording() }

        // Hidden first so the last card never lands in the next shot, even with Show Reco on;
        // a new shot replaces it, a cancelled or failed one brings it back
        screenshots.onWillCapture = { [quickAccess] in quickAccess.hide() }
        screenshots.onDidCapture = { [quickAccess] screenshot in
            if let screenshot {
                quickAccess.show(screenshot)
            } else {
                quickAccess.restore()
            }
        }
    }

    /// Opens the last recording saved since launch in the editor.
    func editLastRecording() {
        guard let url = viewModel.lastRecordingURL else {
            logger.info("No recording to edit yet")
            return
        }
        editorWindows.open(url)
    }

    /// Shows the output folder's recordings, to open one in the editor.
    func showRecordings() {
        editorWindows.showRecordings()
    }

    /// Shows the Web Recording window, to record a web page from a script.
    func showWebRecording() {
        editorWindows.showWebRecording()
    }

    /// Shows the Record with AI Agent panel, to have a coding agent record a web page.
    func showAgentRecording() {
        agentRecordingPanel.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // The agent's command line would otherwise outlive the app
        agentRecording.cancel()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "reco" {
            handle(url)
        }
    }

    // MARK: - Keyboard Shortcuts

    private func registerKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [viewModel] in
            Task { @MainActor in
                await viewModel.toggleRecording()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .pauseRecording) { [viewModel] in
            Task { @MainActor in
                viewModel.togglePause()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .recordWithAgent) { [weak self] in
            Task { @MainActor in
                self?.showAgentRecording()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .selectContent) { [viewModel] in
            Task { @MainActor in
                viewModel.presentPicker()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .selectArea) { [viewModel] in
            Task { @MainActor in
                await viewModel.presentAreaSelection()
            }
        }

        let captures: [(KeyboardShortcuts.Name, @MainActor (ScreenshotController) async -> Void)] = [
            (.captureArea, { await $0.captureArea() }),
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
}
