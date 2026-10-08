//
//  AgentTypingIndicator.swift
//  Reco
//

import SwiftUI

/// Three dots that pulse in turn while the agent works and nothing has been said yet.
struct AgentTypingIndicator: View {
    let agent: AgentKind

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    var body: some View {
        TimelineView(.animation(paused: reducesMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: EditorTheme.tightSpacing + 1) {
                ForEach(0..<3, id: \.self) { index in
                    let pulse = reducesMotion ? 0.5 : (sin(time * 5 - Double(index) * 0.9) + 1) / 2
                    Circle()
                        .fill(EditorTheme.dim)
                        .frame(width: 7, height: 7)
                        .opacity(0.35 + 0.65 * pulse)
                        .scaleEffect(0.85 + 0.15 * pulse)
                }
            }
        }
        .agentBubble(.assistant)
        .agentSide(.leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(agent.displayName) is working")
    }
}

/// The render's percent, once it has started.
struct AgentChatProgress: View {
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            HStack {
                Text("Rendering…")
                    .font(.theme(.callout))
                    .foregroundStyle(EditorTheme.dim)
                Spacer()
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.theme(.callout))
                    .monospacedDigit()
                    .foregroundStyle(EditorTheme.dim)
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
        }
        .agentBubble(.assistant)
        .agentSide(.leading)
        .accessibilityElement(children: .combine)
    }
}
