//
//  WebRecordingView.swift
//  Reco
//

import SwiftUI

/// The Web Recording window's content (spec 0008): three panels floating on the blurred desktop, the agent chat
/// on the left when asked for, the live page with the script's timeline in the middle, and the inspector on the
/// right. The window has no title bar of its own: the middle panel's header holds its name and Render.
struct WebRecordingView: View {
    let viewModel: WebRecordingViewModel

    /// The agent chat's runs; `nil` leaves the window without the agent.
    let agent: AgentRecordingViewModel?

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    var body: some View {
        HStack(spacing: WebPanel.gap) {
            if let agent, viewModel.showsAgent {
                AgentChatView(model: agent, page: viewModel.script.url, openMovie: viewModel.openInEditor, hide: toggleAgent)
                    .frame(width: Self.agentWidth)
                    .webPanel(solid: false)
                    // In and out along the same path, from the edge it sits at
                    .transition(reducesMotion ? .opacity : .move(edge: .leading).combined(with: .opacity))
            }

            VStack(spacing: 0) {
                WebStageHeader(viewModel: viewModel, agent: agent, toggleAgent: toggleAgent, toggleInspector: toggleInspector)
                WebStage(viewModel: viewModel)
                Rectangle()
                    .fill(EditorTheme.hairline)
                    .frame(height: 1)
                WebTimelineView(viewModel: viewModel)
            }
            .frame(minWidth: Self.stageMinimumWidth, maxWidth: .infinity)
            .webPanel(solid: true)

            if viewModel.showsInspector {
                WebRecordingInspector(viewModel: viewModel)
                    .disabled(!viewModel.isEditable)
                    .frame(width: Self.inspectorWidth)
                    .webPanel(solid: false)
                    .transition(reducesMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(WebPanel.gap)
        .ignoresSafeArea()
        .background {
            ZStack {
                BehindWindowBlur()
                EditorTheme.stage.opacity(0.6)
            }
            .ignoresSafeArea()
        }
        // Filling the window, like the editor's root, so SwiftUI never fits the window down to it
        .frame(minWidth: minimumWidth, maxWidth: .infinity, minHeight: 680, maxHeight: .infinity)
        .foregroundStyle(EditorTheme.ink)
    }

    private var minimumWidth: CGFloat {
        var width = Self.stageMinimumWidth + 2 * WebPanel.gap
        if agent != nil, viewModel.showsAgent {
            width += Self.agentWidth + WebPanel.gap
        }
        if viewModel.showsInspector {
            width += Self.inspectorWidth + WebPanel.gap
        }
        return width
    }

    private func toggleAgent() {
        withAnimation(reducesMotion ? EditorTheme.fadeMotion : EditorTheme.motion) {
            viewModel.showsAgent.toggle()
        }
    }

    private func toggleInspector() {
        withAnimation(reducesMotion ? EditorTheme.fadeMotion : EditorTheme.motion) {
            viewModel.showsInspector.toggle()
        }
    }

    /// Wide enough for the chat's messages; the inspector's for its controls. Picked in the Figma design (v6) for
    /// the 1533 pt window.
    private static let agentWidth: CGFloat = 330
    private static let inspectorWidth: CGFloat = 340

    /// The header's title, a usable address bar and Render.
    private static let stageMinimumWidth: CGFloat = 600
}
