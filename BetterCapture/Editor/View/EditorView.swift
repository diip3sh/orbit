//
//  EditorView.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// An editor window's content: the preview and transport on a dark stage, the timeline under them,
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

                    EditorTimelineView(viewModel: viewModel, videoSize: source.naturalSize)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(EditorTheme.panel)
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
                        .prominentEditorButton()
                        .help("Export the edited video")
                    }
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
                ContentUnavailableView(
                    "Can't Open Recording",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(minWidth: 560, minHeight: 440)
        .background(EditorTheme.stage)
        .tint(EditorTheme.accent)
        .editorMotion(.smooth, value: viewModel.source == nil)
        .task {
            await viewModel.load()
        }
    }
}
