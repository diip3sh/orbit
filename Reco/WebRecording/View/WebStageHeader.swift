//
//  WebStageHeader.swift
//  Reco
//

import SwiftUI

/// The stage panel's header, in place of a title bar: the window's name, the page's address with its viewport,
/// Render, and the buttons that show the agent and the inspector. Its empty parts drag the window.
struct WebStageHeader: View {
    @Bindable var viewModel: WebRecordingViewModel

    /// The agent chat's runs; `nil` leaves the window without the agent.
    let agent: AgentRecordingViewModel?

    let toggleAgent: () -> Void
    let toggleInspector: () -> Void

    var body: some View {
        // The leftmost panel holds the window's buttons in its corner
        let isLeading = agent == nil || !viewModel.showsAgent
        HStack(spacing: EditorTheme.mediumSpacing) {
            if agent != nil, !viewModel.showsAgent {
                Button(action: toggleAgent) {
                    Label("Agent", image: "button-agent")
                }
                .buttonStyle(.webPill)
                .help("Have a coding agent script and record this page")
                .transition(.opacity)
            }

            Text("Web Recording")
                .font(.theme(.title3, weight: .semibold))
                .tracking(-0.15)
                .lineLimit(1)
                .fixedSize()

            WebAddressBar(viewModel: viewModel)
                .frame(minWidth: 200, maxWidth: 403)
                .frame(maxWidth: .infinity)

            Button {
                viewModel.render()
            } label: {
                Label {
                    HStack(spacing: EditorTheme.smallSpacing) {
                        Text("Render")
                            .font(.theme(weight: .semibold))
                        Text("⌘↩")
                            .font(.theme(.subheadline, weight: .medium))
                            .opacity(0.7)
                    }
                } icon: {
                    Image(systemName: "arrow.down.to.line")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.editorPrimary)
            .keyboardShortcut(.return, modifiers: .command)
            .help("Render the script into a recording and open it in the editor (⌘↩)")
            // One render at a time: the agent's uses the same renderer
            .disabled(!viewModel.canRender || agent?.isRunning == true)
            .fixedSize()

            Button(viewModel.showsInspector ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.trailing", action: toggleInspector)
                .buttonStyle(EditorIconButtonStyle(diameter: 28))
                .help(viewModel.showsInspector ? "Hide the inspector" : "Show the inspector")
        }
        .padding(.leading, isLeading ? WebPanel.windowButtonsWidth - WebPanel.gap + EditorTheme.mediumSpacing : 20)
        .padding(.trailing, EditorTheme.mediumSpacing)
        .frame(height: WebPanel.headerHeight)
        .dragsWindow()
    }
}
