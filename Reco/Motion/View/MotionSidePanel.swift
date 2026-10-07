//
//  MotionSidePanel.swift
//  Reco
//

import SwiftUI

/// The glass panel beside a motion video's stage: the inspector, and the agent chat that changes the
/// video, with a switch between them on top (as ``EditorSidePanel`` for recordings).
struct MotionSidePanel: View {
    let viewModel: MotionEditorViewModel
    let chat: AgentChatViewModel

    /// The panel the user picked, if they did.
    @State private var picked: EditorSidePanel.Panel?

    private static let width: CGFloat = 320

    /// The picked panel, else the chat when an agent made the video.
    private var panel: Binding<EditorSidePanel.Panel> {
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
            if panel.wrappedValue == .agent {
                AgentChatView(chat: chat)
                    .transition(.materialize(sideways: 48))
            } else {
                MotionInspector(viewModel: viewModel)
                    .transition(.materialize(sideways: -48))
            }
        }
        .editorMotion(value: panel.wrappedValue)
        .editorBar(edge: .top) {
            EditorSegmentedPicker(selection: panel, options: [(.style, "Style"), (.agent, "Agent")])
                .padding(EditorTheme.mediumSpacing)
        }
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .clipShape(shape)
        .editorGlass(in: shape)
        .padding([.trailing, .bottom], EditorTheme.mediumSpacing)
        .task {
            await chat.load()
        }
    }
}
