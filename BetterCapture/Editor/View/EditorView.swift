//
//  EditorView.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// An editor window's content: the preview, transport controls, timeline and inspector.
struct EditorView: View {
    let viewModel: EditorViewModel

    @State private var showsInspector = true
    @State private var showsExport = false

    var body: some View {
        Group {
            if let source = viewModel.source {
                VStack(spacing: 0) {
                    PlayerLayerView(player: viewModel.playback.player)

                    TransportBar(viewModel: viewModel)

                    EditorTimelineView(viewModel: viewModel, videoSize: source.naturalSize)
                        .padding([.horizontal, .bottom])

                    if let error = viewModel.error {
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .padding([.horizontal, .bottom])
                    }
                }
                .inspector(isPresented: $showsInspector) {
                    EditorInspector(viewModel: viewModel)
                        .inspectorColumnWidth(min: 240, ideal: 280)
                }
                .toolbar {
                    Button("Export…", systemImage: "square.and.arrow.up") {
                        showsExport = true
                    }
                    Button("Inspector", systemImage: "sidebar.trailing") {
                        showsInspector.toggle()
                    }
                }
                .sheet(isPresented: $showsExport) {
                    ExportSheet(viewModel: viewModel)
                }
            } else if let error = viewModel.error {
                ContentUnavailableView(
                    "Can't Open Recording",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            } else {
                ProgressView()
            }
        }
        .frame(minWidth: 640, minHeight: 400)
        .task {
            await viewModel.load()
        }
    }
}
