//
//  WebRecordingView.swift
//  Reco
//

import SwiftUI

/// The Web Recording window's content, laid out like the editor: the live page on the stage, the script's
/// timeline under it, the inspector on the right and, when asked for, the agent chat on the left (spec 0008).
struct WebRecordingView: View {
    let viewModel: WebRecordingViewModel

    /// The agent chat's runs; `nil` leaves the window without the agent.
    let agent: AgentRecordingViewModel?

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    var body: some View {
        @Bindable var viewModel = viewModel
        HStack(spacing: 0) {
            if let agent, viewModel.showsAgent {
                AgentChatView(model: agent, page: viewModel.script.url, openMovie: viewModel.openInEditor)
                    .frame(width: Self.panelWidth)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(EditorTheme.hairline)
                            .frame(width: 1)
                    }
                    // In and out along the same path, from the edge the button sits at
                    .transition(reducesMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
            }

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
        }
        .inspector(isPresented: $viewModel.showsInspector) {
            WebRecordingInspector(viewModel: viewModel)
                .disabled(!viewModel.isEditable)
                .inspectorColumnWidth(Self.panelWidth)
        }

        .toolbar {
            if agent != nil {
                ToolbarItem(placement: .navigation) {
                    Button("AI Agent", systemImage: "sparkles") {
                        withAnimation(reducesMotion ? EditorTheme.fadeMotion : EditorTheme.motion) {
                            viewModel.showsAgent.toggle()
                        }
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(.editorGhost)
                    .background(viewModel.showsAgent ? EditorTheme.softHairline : .clear, in: .capsule)
                    .help(viewModel.showsAgent ? "Hide the agent" : "Have a coding agent script and record this page")
                }
                .hidingSharedBackground()
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
                    viewModel.showsInspector.toggle()
                }
                .help(viewModel.showsInspector ? "Hide the inspector" : "Show the inspector")
            }
        }
        // Filling the window, like the editor's root, so SwiftUI never fits the window down to it
        .frame(minWidth: viewModel.showsAgent ? 900 + Self.panelWidth : 900, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
        .editorWindowBackground()
    }

    /// Wide enough for the chat's messages and the inspector's controls, and the editor's inspector's width.
    private static let panelWidth: CGFloat = 340
}
