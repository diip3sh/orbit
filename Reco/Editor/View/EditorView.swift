//
//  EditorView.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// An editor window's content: the preview on the stage, the transport and the timeline under it,
/// and the inspector. Export is a mode of the same window: the timeline slides down out of it, the
/// preview grows into the room, and the inspector shows the export's options; Back (Esc) undoes it.
struct EditorView: View {
    let viewModel: EditorViewModel
    let chat: AgentChatViewModel

    /// The smallest content the window allows: the side panel beside a stage that still shows its transport.
    static let minimumSize = CGSize(width: 900, height: 560)

    @State private var showsInspector = true

    /// The inspector's tab, kept here so it survives a visit to export.
    @State private var inspectorTab = InspectorTab.background

    /// Whether the title bar's name is being edited, which Esc must end before it leaves export.
    @State private var isRenaming = false

    /// The export's visit, while it shows.
    @State private var export: ExportSession?
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    /// Entering and leaving export: critically damped like every state change, a little quicker than
    /// `EditorTheme.motion` since nothing travels far.
    private static let exportMotion = Animation.spring(response: 0.25, dampingFraction: 1)

    /// The side panel the user picked, if they did.
    @State private var pickedPanel: EditorSidePanel.Panel?

    var body: some View {
        Group {
            if let source = viewModel.source {
                VStack(spacing: 0) {
                    EditorStage(viewModel: viewModel)
                    if export == nil {
                        timeline(for: source)
                            .transition(reducesMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    }
                }
                // The timeline leaves below the window's edge, not over it
                .clipped()
                // Solid under the stage and timeline only: the inspector shows the desktop
                .editorWindowBackground()
                // A `.recostyle` file dropped on the editor is kept with the saved styles and applied
                .dropDestination(for: URL.self) { urls, _ in
                    guard let url = urls.first(where: { $0.pathExtension == StylePreset.fileExtension }) else { return false }
                    viewModel.importStyle(from: url)
                    return true
                }
                // One inspector for both modes, so the column stays put and only its content changes: the
                // editor's sections, or the export's options, which always show
                .inspector(isPresented: export == nil ? $showsInspector : .constant(true)) {
                    Group {
                        if let export {
                            ExportOptions(viewModel: viewModel, session: export)
                        } else {
                            EditorSidePanel(viewModel: viewModel, chat: chat, tab: $inspectorTab, picked: $pickedPanel)
                        }
                    }
                    .transition(.opacity)
                    .translucentColumn()
                    .inspectorColumnWidth(min: 300, ideal: EditorInspector.idealWidth, max: 460)
                }
                .toolbar { toolbar }
                .transition(.opacity)
            } else if let error = viewModel.error {
                ContentUnavailableView {
                    Label("Can't Open Recording", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([viewModel.videoURL])
                    } label: {
                        Label("Show in Finder", image: "button-folder")
                    }
                    .buttonStyle(.editorSecondary)
                }
            } else {
                ProgressView("Opening…")
                    .controlSize(.small)
            }
        }
        // Room for the inspector and a preview beside it, and the transport on one row. Filling the window:
        // with only a minimum, the "Opening…" spinner made that minimum the root's largest size too, and
        // SwiftUI shrank the window to it (900×592) as it opened, whatever size it was given
        .frame(minWidth: 900, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
        .foregroundStyle(EditorTheme.ink)
        .background {
            // Opening, or the error: the whole window's ground
            if viewModel.source == nil {
                EditorTheme.stage
                    .ignoresSafeArea()
            }
        }
        .editorMotion(.smooth, value: viewModel.source == nil)
        .task(id: viewModel.videoURL) {
            await viewModel.load()
        }
        .task(id: chat.movie) {
            await chat.load()
        }
    }

    private func timeline(for source: EditorSource) -> some View {
        VStack(spacing: 0) {
            TimelineToolbar(viewModel: viewModel)
                .padding(.horizontal, EditorTheme.spacing)
                .padding(.top, EditorTheme.mediumSpacing)
            EditorTimelineView(viewModel: viewModel, videoSize: source.naturalSize)
                .padding(.horizontal, EditorTheme.spacing * 2)
                .padding(.top, EditorTheme.mediumSpacing)
                .padding(.bottom, EditorTheme.smallSpacing)
        }
        .background(EditorTheme.stage)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if let export {
            // In front of the name, as a browser's back and forward
            ToolbarItem(placement: .navigation) {
                exportNavigation(export)
            }
        }
        ToolbarItem(placement: .navigation) {
            RecordingNameField(name: RecordingRename.displayName(of: viewModel.videoURL), isRenaming: $isRenaming) { name in
                Task { await viewModel.rename(to: name) }
            }
            .disabled(export?.isExporting == true)
        }
        .hidingSharedBackground()
        // With the window's title hidden nothing pushes the buttons to the trailing edge: this does
        if #available(macOS 26, *) {
            ToolbarSpacer(.flexible, placement: .primaryAction)
        } else {
            ToolbarItem(placement: .primaryAction) { Spacer() }
        }
        if export == nil {
            ToolbarItem(placement: .primaryAction) {
                // A circle like the inspector's button: the only glass in the editor is the primary button's
                StyleMenu(viewModel: viewModel)
                    .menuStyle(.button)
                    .menuIndicator(.hidden)
                    .buttonStyle(.editorIcon)
            }
            .hidingSharedBackground()
            if #available(macOS 26, *) {
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: openExport) {
                    Label("Export…", image: "button-export")
                }
                .buttonStyle(.editorPrimary)
                .keyboardShortcut("e")
                .help("Export the edited video")
            }
            .hidingSharedBackground()
            if #available(macOS 26, *) {
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Inspector", systemImage: "sidebar.trailing") {
                    showsInspector.toggle()
                }
                .buttonStyle(.editorIcon)
                .help(showsInspector ? "Hide the inspector" : "Show the inspector")
            }
            .hidingSharedBackground()
        }
    }

    /// Back to the editor; forward has nowhere to go from export, so it is there only to read as the pair.
    private func exportNavigation(_ export: ExportSession) -> some View {
        ControlGroup {
            Button("Editor", systemImage: "chevron.left", action: closeExport)
                // Esc ends a rename first
                .keyboardShortcut(isRenaming ? nil : .cancelAction)
                .disabled(export.isExporting)
                .help("Back to the editor (Esc)")
            Button("Export", systemImage: "chevron.right") {}
                .disabled(true)
        }
        .controlGroupStyle(.navigation)
    }

    /// Export opens and closes on a paused frame: it is for looking, not editing.
    private func openExport() {
        viewModel.playback.pause()
        withAnimation(reducesMotion ? EditorTheme.fadeMotion : Self.exportMotion) {
            export = ExportSession(viewModel: viewModel)
        }
    }

    private func closeExport() {
        viewModel.playback.pause()
        export?.cancel()
        withAnimation(reducesMotion ? EditorTheme.fadeMotion : Self.exportMotion) {
            export = nil
        }
    }
}
