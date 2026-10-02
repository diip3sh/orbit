//
//  AgentChatEmptyState.swift
//  Reco
//

import SwiftUI

/// The chat before its first message: what the agent does, and requests to start from, which go
/// into the message box.
struct AgentChatEmptyState: View {
    let pick: (String) -> Void

    private static let suggestions = ["Slower, with longer pauses", "Also hover the pricing table", "End on the footer"]

    var body: some View {
        VStack(spacing: EditorTheme.spacing) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(EditorTheme.dim)
                .frame(width: 44, height: 44)
                .background(EditorTheme.tray, in: .circle)
                .accessibilityHidden(true)

            VStack(spacing: EditorTheme.tightSpacing) {
                Text("Direct the next take")
                    .font(.headline)
                Text("Say what to change. The agent records the page again and shows it here, in the same style.")
                    .font(.callout)
                    .foregroundStyle(EditorTheme.dim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: EditorTheme.tightSpacing) {
                ForEach(Self.suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        pick(suggestion)
                    }
                    .buttonStyle(SuggestionButtonStyle())
                }
            }
        }
        .padding(EditorTheme.largeSpacing)
    }
}

/// A capsule on a quiet fill that lights up under the pointer.
private struct SuggestionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Suggestion(configuration: configuration)
    }

    private struct Suggestion: View {
        let configuration: ButtonStyleConfiguration

        @State private var isHovered = false

        var body: some View {
            let isLit = isHovered || configuration.isPressed

            configuration.label
                .font(.callout)
                .foregroundStyle(isLit ? EditorTheme.ink : EditorTheme.dim)
                .padding(.horizontal, EditorTheme.mediumSpacing)
                .padding(.vertical, EditorTheme.smallSpacing - 2)
                .background(.primary.opacity(configuration.isPressed ? 0.12 : isHovered ? 0.08 : 0.05), in: .capsule)
                .contentShape(.capsule)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .onHover { isHovered = $0 }
                // The press shows on the frame it lands; only hover and release ease
                .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: isLit)
        }
    }
}
