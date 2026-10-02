//
//  EditorView.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// An editor window's content: the preview and transport on the stage, the timeline in a tray under them,
/// and the side panel floating on glass beside them.
struct EditorView: View {
    let viewModel: EditorViewModel
    let chat: AgentChatViewModel

    /// The smallest content the window allows: the side panel beside a stage that still shows its transport.
    static let minimumSize = CGSize(width: 900, height: 560)

    @State private var showsInspector = true
    @State private var showsExport = false

    /// The side panel the user picked, if they did.
    @State private var pickedPanel: EditorSidePanel.Panel?

    var body: some View {
        Group {
            if let source = viewModel.source {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        EditorStage(viewModel: viewModel)

                        EditorTimelineView(viewModel: viewModel, videoSize: source.naturalSize)
                            .padding(.horizontal, EditorTheme.spacing)
                            .padding(.vertical, EditorTheme.mediumSpacing)
                            .background(EditorTheme.tray, in: EditorTheme.trayShape)
                            .overlay {
                                EditorTheme.trayShape.strokeBorder(EditorTheme.hairline)
                            }
                            .padding([.horizontal, .bottom], EditorTheme.mediumSpacing)
                    }

                    if showsInspector {
                        EditorSidePanel(viewModel: viewModel, chat: chat, picked: $pickedPanel)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                // A take the agent recorded again replaces this one in the window: its views start over
                .id(viewModel.videoURL)
                .editorMotion(value: showsInspector)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Export…", systemImage: "square.and.arrow.up") {
                            showsExport = true
                        }
                        .labelStyle(.titleAndIcon)
                        .buttonStyle(.editorPrimary)
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
        .frame(minWidth: Self.minimumSize.width, minHeight: Self.minimumSize.height)
        .editorWindowBackground()
        .editorMotion(.smooth, value: viewModel.source == nil)
        .task(id: viewModel.videoURL) {
            await viewModel.load()
        }
        .task(id: chat.movie) {
            await chat.load()
        }
    }
}
