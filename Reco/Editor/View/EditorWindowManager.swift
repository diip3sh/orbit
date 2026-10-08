//
//  EditorWindowManager.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import AppKit
import SwiftUI

/// Opens one editor window per recording, the Library window and the Web Recording window, and
/// keeps the app in the Dock while any is open.
///
/// The app is a menu bar app (`LSUIElement`), and its entry points - notifications, URLs, the menu
/// bar - have no SwiftUI window environment, so editor windows are AppKit windows hosting SwiftUI.
@MainActor
final class EditorWindowManager: NSObject {

    private struct Editor {
        let window: NSWindow
        let viewModel: EditorViewModel

        /// Whether the output folder's security scope was started for this window.
        let accessesOutputDirectory: Bool
    }

    private struct Library {
        let window: NSWindow
        let viewModel: LibraryViewModel
        let watcher: FolderWatcher
        let accessesOutputDirectory: Bool
    }

    private struct WebRecording {
        let window: NSWindow
        let viewModel: WebRecordingViewModel
    }

    private let settings: SettingsStore
    private var editors: [URL: Editor] = [:]
    private var library: Library?
    private var webRecording: WebRecording?

    /// What the Library's New menu starts; set by `AppDelegate`
    var libraryActions = LibraryViewModel.Actions()

    /// The agent runs the Web Recording window's Agent tab shows and starts; set by `AppDelegate`
    var agentRecording: AgentRecordingViewModel?

    /// The open Web Recording window's state, which follows what an agent does (spec 0008)
    var webRecordingViewModel: WebRecordingViewModel? {
        webRecording?.viewModel
    }

    /// The Web Recording window for an agent to browse in (spec 0011): the open one, or opened with its
    /// last script, without taking focus from the agent's window.
    func webRecordingForAgent() -> WebRecordingViewModel? {
        if let webRecording {
            return webRecording.viewModel
        }
        let webRecording = makeWebRecording()
        webRecording.window.orderFront(nil)
        return webRecording.viewModel
    }

    init(settings: SettingsStore) {
        self.settings = settings
    }

    /// Opens the editor for a recording in the output folder, or brings its window forward.
    func open(_ videoURL: URL) {
        let videoURL = videoURL.standardizedFileURL
        if let window = editors[videoURL]?.window {
            activate(window)
            return
        }

        // Held while the window is open: the project autosaves next to the recording
        let accessesOutputDirectory = settings.startAccessingOutputDirectory()

        let viewModel = EditorViewModel(videoURL: videoURL)
        let hostingController = NSHostingController(rootView: EditorView(viewModel: viewModel).themed())
        // Only the minimum size, so the window doesn't resize itself to fit the loading placeholder
        hostingController.sizingOptions = .minSize
        // The name field, export and inspector buttons are SwiftUI toolbar items. The title isn't bridged: the
        // window keeps it for the Window menu, hidden, since SwiftUI draws a bridged title whatever titleVisibility
        // says, and removing it from its toolbar also took the space that holds the buttons at the trailing edge
        hostingController.sceneBridgingOptions = [.toolbars]
        let window = makeWindow(hostingController, title: videoURL.deletingPathExtension().lastPathComponent, size: NSSize(width: 1533, height: 943))
        window.representedURL = videoURL
        window.titleVisibility = .hidden
        editors[videoURL] = Editor(window: window, viewModel: viewModel, accessesOutputDirectory: accessesOutputDirectory)
        // A renamed recording is found, and reopened, under its new name
        viewModel.onRename = { [weak self] old, new in
            guard let self, let editor = editors.removeValue(forKey: old.standardizedFileURL) else { return }
            editors[new.standardizedFileURL] = editor
            editor.window.representedURL = new
            editor.window.title = new.deletingPathExtension().lastPathComponent
        }

        // A regular app gets a Dock icon, ⌘-Tab and the main menu with Undo and Redo
        NSApp.setActivationPolicy(.regular)
        activate(window)
    }

    /// Shows the Library, Reco's main window, or brings it forward (spec 0010).
    func showLibrary() {
        if let library {
            activate(library.window)
            return
        }

        // Held while the window is open: it lists the folder and reads the recordings' pictures
        let accessesOutputDirectory = settings.startAccessingOutputDirectory()
        let settings = settings
        let openMovie: (URL) -> Void = { [weak self] url in
            self?.open(url)
        }
        let viewModel = LibraryViewModel(
            folders: { LibraryFolders(recordings: settings.outputDirectory, screenshots: settings.screenshotDirectory, history: ScreenshotHistory.directory) },
            actions: libraryActions,
            openMovie: openMovie
        )
        let hostingController = NSHostingController(rootView: LibraryView(viewModel: viewModel).themed())
        hostingController.sizingOptions = .minSize
        hostingController.sceneBridgingOptions = [.toolbars]
        let window = makeWindow(hostingController, title: "Reco", size: NSSize(width: 1100, height: 720))
        library = Library(window: window, viewModel: viewModel, watcher: FolderWatcher(), accessesOutputDirectory: accessesOutputDirectory)

        NSApp.setActivationPolicy(.regular)
        activate(window)
    }

    /// Shows the Web Recording window with a blank script, as New Web Recording means; the last one is
    /// an undo away. Each render opens in the editor.
    func showNewWebRecording() {
        if let webRecording {
            webRecording.viewModel.startNew()
            activate(webRecording.window)
            return
        }

        let webRecording = makeWebRecording()
        webRecording.viewModel.startNew()
        activate(webRecording.window)
    }

    /// The Web Recording window with its agent panel open, where Record with AI Agent starts: a blank page and a
    /// new conversation, unless an agent is still running in it.
    func showAgentChat() {
        let webRecording = webRecording ?? makeWebRecording()
        if agentRecording?.isRunning != true {
            webRecording.viewModel.startNew()
            agentRecording?.startNewChat()
        }
        withMotion { webRecording.viewModel.showsAgent = true }
        activate(webRecording.window)
    }

    /// The Web Recording window with its last script, kept until it closes. Each render opens in the editor.
    private func makeWebRecording() -> WebRecording {
        let viewModel = WebRecordingViewModel(settings: settings) { [weak self] url in
            self?.agentRecording?.didRender(url)
            self?.open(url)
        }
        let hostingController = NSHostingController(rootView: WebRecordingView(viewModel: viewModel, agent: agentRecording).themed())
        hostingController.sizingOptions = .minSize
        hostingController.sceneBridgingOptions = [.toolbars]
        let window = makeWindow(hostingController, title: "Web Recording", size: NSSize(width: 1533, height: 943))
        let webRecording = WebRecording(window: window, viewModel: viewModel)
        self.webRecording = webRecording
        NSApp.setActivationPolicy(.regular)
        return webRecording
    }

    /// A centred window in the editor's look: the content running under a transparent title bar and toolbar.
    private func makeWindow(_ contentViewController: NSViewController, title: String, size: NSSize) -> NSWindow {
        let window = NSWindow(contentViewController: contentViewController)
        window.title = title
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.backgroundColor = .windowBackgroundColor
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.delegate = self
        // Never larger than the screen it opens on, with a little desktop showing around it.
        let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame.size ?? size
        window.setContentSize(NSSize(width: min(size.width, visible.width - 40), height: min(size.height, visible.height - 40)))
        window.center()
        return window
    }

    private func activate(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func editor(for window: NSWindow) -> (videoURL: URL, editor: Editor)? {
        editors.first { $0.value.window === window }.map { ($0.key, $0.value) }
    }
}

// MARK: - NSWindowDelegate

extension EditorWindowManager: NSWindowDelegate {

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        if let webRecording, window === webRecording.window {
            return webRecording.viewModel.undoManager
        }
        return editor(for: window)?.editor.viewModel.undoManager
    }

    /// The Library is read whenever it comes forward, and its folders watched, which Settings may have
    /// changed meanwhile.
    func windowDidBecomeKey(_ notification: Notification) {
        guard let library, notification.object as? NSWindow === library.window else { return }
        library.watcher.watch(library.viewModel.watchedFolders) {
            Task { await library.viewModel.reload() }
        }
        Task {
            await library.viewModel.reload()
        }
    }

    /// Closing the Web Recording window stops its render, so it asks first while one runs.
    func windowShouldClose(_ window: NSWindow) -> Bool {
        guard let webRecording, window === webRecording.window, !webRecording.viewModel.isEditable else { return true }
        let alert = NSAlert()
        alert.messageText = "Stop Rendering?"
        alert.informativeText = "Closing the window stops the render. Nothing is saved."
        alert.addButton(withTitle: "Keep Rendering")
        alert.addButton(withTitle: "Stop and Close").hasDestructiveAction = true
        return alert.runModal() == .alertSecondButtonReturn
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if let library, window === library.window {
            self.library = nil
            library.watcher.stop()
            if library.accessesOutputDirectory {
                settings.stopAccessingOutputDirectory()
            }
        } else if let webRecording, window === webRecording.window {
            self.webRecording = nil
            webRecording.viewModel.close()
        } else if let (videoURL, editor) = editor(for: window) {
            editors[videoURL] = nil
            let settings = settings
            Task {
                // Saving needs the folder, so its scope is released only afterwards
                await editor.viewModel.close()
                if editor.accessesOutputDirectory {
                    settings.stopAccessingOutputDirectory()
                }
            }
        }
        if editors.isEmpty, library == nil, webRecording == nil {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
