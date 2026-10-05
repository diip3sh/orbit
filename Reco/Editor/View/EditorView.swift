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

    var body: some View {
        Group {
            if let source = viewModel.source {
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
                        Button("Export…", systemImage: "square.and.arrow.up") {
                            showsExport = true
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonStyle(.editorAccent)
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
                .sheet(isPresented: $showsExport) {
                    ExportSheet(viewModel: viewModel)
                }
                .transition(.opacity)
            } else if let error = viewModel.error {
                ContentUnavailableView {
                    Label("Can't Open Recording", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([viewModel.videoURL])
                    }
                    .buttonStyle(.editorGhost)
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
}
