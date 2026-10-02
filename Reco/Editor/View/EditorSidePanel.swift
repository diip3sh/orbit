//
//  EditorSidePanel.swift
//  Reco
//

import SwiftUI

/// The glass panel floating beside the stage: the inspector, and for a web take the agent chat,
/// with a switch between them on top.
struct EditorSidePanel: View {
    let viewModel: EditorViewModel
    let chat: AgentChatViewModel

    /// The panel the user picked, if they did.
    @Binding var picked: Panel?

    /// What the panel shows.
    enum Panel {
        case style
        case agent
    }

    private static let width: CGFloat = 320

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
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        // Each panel comes in from its side of the switch and leaves that way
        ZStack {
            if chat.isAvailable, panel.wrappedValue == .agent {
                AgentChatView(chat: chat)
                    .transition(.materialize(sideways: 48))
            } else {
                EditorInspector(viewModel: viewModel)
                    .transition(.materialize(sideways: -48))
            }
        }
        .editorMotion(value: panel.wrappedValue)
        .editorBar(edge: .top) {
            if chat.isAvailable {
                EditorSegmentedPicker(selection: panel, options: [(.style, "Style"), (.agent, "Agent")])
                    .padding(EditorTheme.mediumSpacing)
            }
        }
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .clipShape(shape)
        .editorGlass(in: shape)
        .padding([.trailing, .bottom], EditorTheme.mediumSpacing)
    }
}
