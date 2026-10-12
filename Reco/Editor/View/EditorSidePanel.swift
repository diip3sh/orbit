//
//  EditorSidePanel.swift
//  Reco
//

import SwiftUI

/// The editor's inspector and agent chat, with a switch between them.
struct EditorSidePanel: View {
    let viewModel: EditorViewModel
    let chat: AgentChatViewModel
    @Binding var tab: InspectorTab

    /// The panel the user picked, if they did.
    @Binding var picked: Panel?

    /// What the panel shows.
    enum Panel {
        case style
        case agent
    }

    /// The picked panel, else the chat when an agent made the take.
    private var panel: Binding<Panel> {
        Binding {
            picked ?? (chat.conversation.isEmpty ? .style : .agent)
        } set: {
            picked = $0
        }
    }

    var body: some View {
        let panel = panel
        VStack(spacing: 0) {
            if chat.isAvailable {
                EditorSegmentedPicker(selection: panel, options: [(.style, "Style"), (.agent, "Agent")])
                    .padding(EditorTheme.mediumSpacing)
            }
            if chat.isAvailable, panel.wrappedValue == .agent {
                EditorAgentChatView(chat: chat)
            } else {
                EditorInspector(viewModel: viewModel, tab: $tab)
            }
        }
        .editorMotion(value: panel.wrappedValue)
    }
}
