//
//  EditorView.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// An editor window's content: the preview and transport on a dark stage, the timeline under them,
/// and the inspector, which for a web take can show the agent chat instead.
struct EditorView: View {
    let viewModel: EditorViewModel
    let chat: AgentChatViewModel

    @State private var showsInspector = true
    @State private var showsExport = false

    /// The panel the user picked, if they did.
    @State private var pickedPanel: Panel?

    /// What the inspector's column shows.
    private enum Panel {
        case style
        case agent
    }

    /// The picked panel, else the chat when an agent made the take.
    private var panel: Binding<Panel> {
        Binding {
            pickedPanel ?? (chat.conversation.isEmpty ? .style : .agent)
        } set: {
            pickedPanel = $0
        }
    }

    var body: some View {
        Group {
            if let source = viewModel.source {
                VStack(spacing: 0) {
                    EditorStage(viewModel: viewModel)

                    EditorTimelineView(viewModel: viewModel, videoSize: source.naturalSize)
                        .padding(.horizontal, EditorTheme.largeSpacing)
                        .padding(.vertical, EditorTheme.spacing)
                        .background(EditorTheme.panel.opacity(0.6))
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(EditorTheme.hairline)
                                .frame(height: 1)
                        }
                }
                // A take the agent recorded again replaces this one in the window: its views start over
                .id(viewModel.videoURL)
                .inspector(isPresented: $showsInspector) {
                    VStack(spacing: 0) {
                        if chat.isAvailable {
                            Picker("Panel", selection: panel) {
                                Text("Style").tag(Panel.style)
                                Text("Agent").tag(Panel.agent)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .padding([.horizontal, .top])
                        }
                        if chat.isAvailable, panel.wrappedValue == .agent {
                            AgentChatView(chat: chat)
                        } else {
                            EditorInspector(viewModel: viewModel)
                        }
                    }
                    .id(viewModel.videoURL)
                    .inspectorColumnWidth(min: 260, ideal: 300, max: 380)
                }
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
        .frame(minWidth: 560, minHeight: 440)
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
