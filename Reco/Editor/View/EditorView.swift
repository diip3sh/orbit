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

    /// The inspector's width, which its leading edge drags between the old column's limits.
    @AppStorage("editorInspectorWidth") private var inspectorWidth = EditorInspector.idealWidth

    /// Whether the header's name is being edited, which Esc must end before it leaves export.
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
                HStack(spacing: EditorTheme.smallSpacing) {
                    VStack(spacing: 0) {
                        EditorHeader(
                            viewModel: viewModel,
                            export: export,
                            isRenaming: $isRenaming,
                            showsInspector: $showsInspector,
                            openExport: openExport,
                            closeExport: closeExport
                        )
                        EditorStage(viewModel: viewModel)
                        if export == nil {
                            timeline(for: source)
                                .transition(reducesMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    // The timeline leaves below the panel's edge, not over it
                    .editorPanel()
                    // A `.recostyle` file dropped on the editor is kept with the saved styles and applied
                    .dropDestination(for: URL.self) { urls, _ in
                        guard let url = urls.first(where: { $0.pathExtension == StylePreset.fileExtension }) else { return false }
                        viewModel.importStyle(from: url)
                        return true
                    }

                    // One panel for both modes, so it stays put and only its content changes: the editor's
                    // sections, or the export's options, which always show
                    if export != nil || showsInspector {
                        Group {
                            if let export {
                                ExportOptions(viewModel: viewModel, session: export)
                            } else {
                                EditorSidePanel(viewModel: viewModel, chat: chat, tab: $inspectorTab, picked: $pickedPanel)
                            }
                        }
                        .transition(.opacity)
                        .frame(width: CGFloat(inspectorWidth))
                        .frame(maxHeight: .infinity)
                        .editorPanel()
                        .overlay(alignment: .leading) {
                            InspectorResizeHandle(width: $inspectorWidth)
                        }
                        .transition(reducesMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(EditorTheme.smallSpacing)
                .ignoresSafeArea()
                .editorMotion(value: showsInspector)
                .editorWindowBackground()
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
        // The traffic lights in the main panel's header row, also while it opens
        .background(SettingsWindowConfigurator(rowHeight: EditorHeader.height))
        .task(id: viewModel.videoURL) {
            await viewModel.load()
        }
        .task(id: chat.movie) {
            await chat.load()
        }
    }

    private func timeline(for source: EditorSource) -> some View {
        VStack(spacing: 0) {
            EditorTheme.ink.opacity(0.06)
                .frame(height: 1)
            VStack(spacing: 0) {
                TimelineToolbar(viewModel: viewModel)
                    .padding(.top, EditorTheme.mediumSpacing)
                EditorTimelineView(viewModel: viewModel, videoSize: source.naturalSize)
                    // The tracks' names sit in this margin, beside their rows
                    .padding(.leading, EditorTimelineView.trackLabelWidth)
                    .padding(.top, EditorTheme.tightSpacing)
                    .padding(.bottom, EditorTheme.spacing)
            }
            .padding(.horizontal, 20)
        }
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

private extension View {

    /// One of the window's two panels: solid, rounded, with a faint edge, on the window's darker ground.
    func editorPanel() -> some View {
        let shape = RoundedRectangle(cornerRadius: EditorTheme.largeRadius)
        return background(EditorTheme.panel, in: shape)
            .clipShape(shape)
            .overlay(shape.strokeBorder(EditorTheme.ink.opacity(0.05)))
    }
}
