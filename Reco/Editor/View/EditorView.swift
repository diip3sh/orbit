//
//  EditorView.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// An editor window's content: the preview on the stage, the transport and the timeline under it,
/// and the inspector.
struct EditorView: View {
    let viewModel: EditorViewModel

    @State private var showsInspector = true
    @State private var showsExport = false
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    var body: some View {
        Group {
            if let source = viewModel.source {
                // Export is a page pushed over the editor, and Back returns to it: it slides in from the
                // trailing edge and leaves the same way, the editor stepping aside under it
                ZStack {
                    if showsExport {
                        ExportPage(viewModel: viewModel) { showsExport = false }
                            .transition(reducesMotion ? .opacity : .move(edge: .trailing))
                    } else {
                        editor(for: source)
                            .transition(reducesMotion ? .opacity : .offset(x: -80).combined(with: .opacity))
                    }
                }
                .editorMotion(value: showsExport)
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

    private func editor(for source: EditorSource) -> some View {
        VStack(spacing: 0) {
            EditorStage(viewModel: viewModel)

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
        .inspector(isPresented: $showsInspector) {
            EditorInspector(viewModel: viewModel)
                .inspectorColumnWidth(min: 260, ideal: 300, max: 380)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.playback.pause()
                    showsExport = true
                } label: {
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
}
