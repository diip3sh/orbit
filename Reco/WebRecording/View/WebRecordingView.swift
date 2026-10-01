//
//  WebRecordingView.swift
//  Reco
//

import SwiftUI

/// The Web Recording window's content: the live page on the stage, the script's timeline under it,
/// the inspector, and Render.
struct WebRecordingView: View {
    let viewModel: WebRecordingViewModel

    @State private var showsInspector = true

    var body: some View {
        VStack(spacing: 0) {
            WebStage(viewModel: viewModel)

            WebTimelineView(viewModel: viewModel)
                .padding(.horizontal, EditorTheme.largeSpacing)
                .padding(.vertical, EditorTheme.spacing)
                .background(EditorTheme.panel.opacity(0.6))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(EditorTheme.hairline)
                        .frame(height: 1)
                }
        }
        .inspector(isPresented: $showsInspector) {
            WebRecordingInspector(viewModel: viewModel)
                .inspectorColumnWidth(min: 260, ideal: 300, max: 380)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Render", systemImage: "film") {
                    viewModel.render()
                }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.editorPrimary)
                .help("Render the script into a recording and open it in the editor")
                .disabled(!viewModel.canRender)
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
        .frame(minWidth: 760, minHeight: 560)
        .editorWindowBackground()
    }
}
