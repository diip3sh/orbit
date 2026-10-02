//
//  AgentChatStatus.swift
//  Reco
//

import SwiftUI

/// How a run is going: a breathing sparkle and the step, with a light passing over it.
struct AgentChatStatus: View {
    let status: String

    var body: some View {
        Label {
            Text(status)
                .monospacedDigit()
                .contentTransition(.numericText())
                .modifier(Shimmer())
        } icon: {
            Image(systemName: "sparkles")
                .foregroundStyle(EditorTheme.dim)
                .symbolEffect(.breathe)
        }
        .font(.callout)
        .editorMotion(value: status)
        .accessibilityElement(children: .combine)
    }
}

/// Dim text with a band of ink crossing it every 1.6 s; just dim with Reduce Motion.
private struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    private static let period = 1.6

    func body(content: Content) -> some View {
        content
            .foregroundStyle(EditorTheme.dim)
            .overlay {
                if !reducesMotion {
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                        let elapsed = timeline.date.timeIntervalSinceReferenceDate
                        // From one band's width before the text to one after it
                        let phase = elapsed.truncatingRemainder(dividingBy: Self.period) / Self.period * 2 - 1

                        content
                            .foregroundStyle(EditorTheme.ink)
                            .mask {
                                LinearGradient(colors: [.clear, .black, .clear], startPoint: .leading, endPoint: .trailing)
                                    .visualEffect { band, proxy in
                                        band.offset(x: phase * proxy.size.width)
                                    }
                            }
                    }
                    .accessibilityHidden(true)
                }
            }
    }
}
