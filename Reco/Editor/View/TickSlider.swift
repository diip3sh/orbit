//
//  TickSlider.swift
//  Reco
//
//  Created by Diip3sh on 05.10.26.
//

import SwiftUI

/// A slider drawn as a ruler: a track with tick marks, filled in the accent colour up to a bar at the
/// value. Dragging moves the value 1:1 from where it was grabbed; a press away from the bar takes it
/// there first. VoiceOver adjusts it in 20 steps. Not focusable: the editor's ← and → are key equivalents
/// (frame steps) that run before a focused view sees the key, so focus only drew a ring around the track.
struct TickSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>

    /// The value as read out, e.g. "8%".
    let valueLabel: Text

    /// The value where the current drag began, in the range.
    @State private var dragStart: Double?
    @Environment(\.isEnabled) private var isEnabled

    static let height: CGFloat = 22

    /// Spaces between ticks, and how far one VoiceOver step moves the value.
    private static let divisions = 20

    /// How near the bar a press grabs it rather than moving it there.
    private static let grabDistance: CGFloat = 8

    var body: some View {
        let span = range.upperBound - range.lowerBound
        let fraction = span > 0 ? (value.clamped(to: range) - range.lowerBound) / span : 0
        let shape = RoundedRectangle(cornerRadius: 6)

        GeometryReader { proxy in
            let width = proxy.size.width
            let barX = fraction * width

            ZStack(alignment: .leading) {
                shape.fill(EditorTheme.control)

                Rectangle()
                    .fill(EditorTheme.accent.opacity(0.28))
                    .frame(width: barX)

                Canvas { context, size in
                    var ticks = Path()
                    for index in 1..<Self.divisions {
                        let tickX = (CGFloat(index) / CGFloat(Self.divisions) * size.width).rounded()
                        let height = index.isMultiple(of: 5) ? size.height * 0.4 : size.height * 0.24
                        ticks.addRect(CGRect(x: tickX, y: (size.height - height) / 2, width: 1, height: height))
                    }
                    context.fill(ticks, with: .color(EditorTheme.faint))
                }

                Capsule()
                    .fill(EditorTheme.accent)
                    .frame(width: dragStart == nil ? 3 : 4, height: Self.height - 6)
                    .offset(x: min(max(barX - 2, 2), width - 6))
            }
            .clipShape(shape)
            .contentShape(shape)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard width > 0, span > 0 else { return }
                        if dragStart == nil {
                            let grabbed = abs(drag.startLocation.x - barX) <= Self.grabDistance
                            dragStart = grabbed ? value : range.lowerBound + drag.startLocation.x / width * span
                        }
                        value = ((dragStart ?? value) + drag.translation.width / width * span).clamped(to: range)
                    }
                    .onEnded { _ in dragStart = nil }
            )
        }
        .frame(height: Self.height)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityValue(valueLabel)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1)
            case .decrement: step(by: -1)
            @unknown default: break
            }
        }
    }

    private func step(by steps: Int) {
        let span = range.upperBound - range.lowerBound
        value = (value + Double(steps) * span / Double(Self.divisions)).clamped(to: range)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
