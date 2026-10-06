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

    @State private var showsInspector = true

    /// Whether the title bar's name is being edited, which Esc must end before it leaves export.
    @State private var isRenaming = false

    /// The export's visit, while it shows.
    @State private var export: ExportSession?
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    /// Entering and leaving export: critically damped like every state change, a little quicker than
    /// `EditorTheme.motion` since nothing travels far.
    private static let exportMotion = Animation.spring(response: 0.25, dampingFraction: 1)

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
                // One inspector for both modes, so the column stays put and only its content changes: the
                // editor's sections, or the export's options, which always show
                .inspector(isPresented: export == nil ? $showsInspector : .constant(true)) {
                    Group {
                        if let export {
                            ExportOptions(viewModel: viewModel, session: export, isRenaming: isRenaming, back: closeExport)
                        } else {
                            EditorInspector(viewModel: viewModel)
                        }
                    }
                    .transition(.opacity)
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
        .editorWindowBackground()
        .editorMotion(.smooth, value: viewModel.source == nil)
        .task {
            await viewModel.load()
        }
    }

    private func timeline(for source: EditorSource) -> some View {
        VStack(spacing: EditorTheme.smallSpacing) {
            TransportBar(viewModel: viewModel)
            EditorTimelineView(viewModel: viewModel, videoSize: source.naturalSize)
        }
        .padding(.horizontal, EditorTheme.largeSpacing)
        .padding(.top, EditorTheme.smallSpacing)
        .padding(.bottom, EditorTheme.spacing)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(EditorTheme.hairline)
                .frame(height: 1)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
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
                .help(showsInspector ? "Hide the inspector" : "Show the inspector")
            }
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
