//
//  WebRecordingView.swift
//  Reco
//

import SwiftUI

/// The Web Recording window's content: the live page on the stage, the script's timeline under it,
/// the inspector or the agent chat beside them (spec 0008), and Render.
struct WebRecordingView: View {
    let viewModel: WebRecordingViewModel

    /// The agent chat's runs; `nil` leaves the window without an Agent tab.
    let agent: AgentRecordingViewModel?

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 0) {
            WebStage(viewModel: viewModel)

            WebTimelineView(viewModel: viewModel)
                .padding(.horizontal, EditorTheme.largeSpacing)
                .padding(.top, EditorTheme.smallSpacing)
                .padding(.bottom, EditorTheme.spacing)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(EditorTheme.hairline)
                        .frame(height: 1)
                }
        }
        .inspector(isPresented: $viewModel.showsSidePanel) {
            Group {
                if viewModel.sidePanel == .agent, let agent {
                    AgentChatView(model: agent, page: viewModel.script.url)
                } else {
                    WebRecordingInspector(viewModel: viewModel)
                        .disabled(!viewModel.isEditable)
                }
            }
            // One width for both panels, so switching doesn't move the page
            .inspectorColumnWidth(Self.sidePanelWidth)
        }

        .toolbar {
            if agent != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("AI Agent", systemImage: "sparkles") {
                        viewModel.toggle(.agent)
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(.editorGhost)
                    .background(viewModel.isShowing(.agent) ? EditorTheme.softHairline : .clear, in: .capsule)
                    .help(viewModel.isShowing(.agent) ? "Hide the agent" : "Have a coding agent script and record this page")
                }
                .hidingSharedBackground()
                if #available(macOS 26, *) {
                    ToolbarSpacer(.fixed, placement: .primaryAction)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Render", systemImage: "film") {
                    viewModel.render()
                }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.editorAccent)
                .help("Render the script into a recording and open it in the editor")
                // One render at a time: the agent's uses the same renderer
                .disabled(!viewModel.canRender || agent?.isRunning == true)
            }
            .hidingSharedBackground()
            if #available(macOS 26, *) {
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Inspector", systemImage: "sidebar.trailing") {
                    viewModel.toggle(.inspector)
                }
                .help(viewModel.isShowing(.inspector) ? "Hide the inspector" : "Show the inspector")
            }
        }
        // Filling the window, like the editor's root, so SwiftUI never fits the window down to it
        .frame(minWidth: 900, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
        .editorWindowBackground()
    }

    /// Wide enough for the chat's messages and the inspector's controls.
    private static let sidePanelWidth: CGFloat = 340
}
