//
//  SliderBar.swift
//  Reco
//

import SwiftUI

/// A slider as a bar of its own: the title in a chip on the left, a hairline track with dot ticks, filled
/// up to a caret at the value, and the value on the right edge. Dragging moves the value 1:1 from where it
/// was grabbed; a press away from the caret takes it there first. The frame section's sliders (padding,
/// corners, shadow, border) use it; `InspectorSlider` stays for sliders inside a card.
struct SliderBar: View {
    let title: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>

    /// The value as shown, e.g. "8%".
    let label: (Double) -> Text

    init(_ title: LocalizedStringKey, value: Binding<Double>, in range: ClosedRange<Double>, label: @escaping (Double) -> Text) {
        self.title = title
        _value = value
        self.range = range
        self.label = label
    }

    /// The value where the current drag began, in the range.
    @State private var dragStart: Double?
    @Environment(\.isEnabled) private var isEnabled

    /// The tick dots split the track into this many parts; one VoiceOver step moves one part.
    private static let divisions = 10

    /// How near the caret a press grabs it rather than moving it there.
    private static let grabDistance: CGFloat = 8

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.theme(.callout, weight: .medium))
                .foregroundStyle(EditorTheme.ink)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(EditorTheme.control, in: .rect(cornerRadius: 7, style: .continuous))
                .padding(.leading, 4)

            track
                .frame(maxWidth: .infinity)

            label(value)
                .font(.theme(.callout).monospacedDigit())
                .foregroundStyle(EditorTheme.dim)
                .frame(minWidth: 28, alignment: .trailing)
                .padding(.trailing, 12)
        }
        .frame(height: 40)
        .background(EditorTheme.panel, in: .rect(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(EditorTheme.hairline)
        }
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityValue(label(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1)
            case .decrement: step(by: -1)
            @unknown default: break
            }
        }
    }

    private var track: some View {
        let span = range.upperBound - range.lowerBound
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let fraction = span > 0 ? (clamped - range.lowerBound) / span : 0

        return GeometryReader { proxy in
            let width = proxy.size.width
            let caretX = fraction * width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.14))
                    .frame(height: 2)

                Canvas { context, size in
                    var dots = Path()
                    for index in 1..<Self.divisions {
                        let tickX = (CGFloat(index) / CGFloat(Self.divisions) * size.width).rounded()
                        dots.addEllipse(in: CGRect(x: tickX - 1, y: size.height / 2 - 1, width: 2, height: 2))
                    }
                    context.fill(dots, with: .color(.primary.opacity(0.22)))
                }

                Capsule()
                    .fill(EditorTheme.ink.opacity(0.8))
                    .frame(width: caretX, height: 2)

                RoundedRectangle(cornerRadius: 1.25, style: .continuous)
                    .fill(EditorTheme.ink)
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                    .frame(width: 2.5, height: 16)
                    .offset(x: min(max(caretX - 1.25, 0), width - 2.5))
            }
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard width > 0, span > 0 else { return }
                        if dragStart == nil {
                            let grabbed = abs(drag.startLocation.x - caretX) <= Self.grabDistance
                            dragStart = grabbed ? value : range.lowerBound + drag.startLocation.x / width * span
                        }
                        let moved = (dragStart ?? value) + drag.translation.width / width * span
                        value = min(max(moved, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in dragStart = nil }
            )
        }
    }

    private func step(by steps: Int) {
        let span = range.upperBound - range.lowerBound
        let stepped = value + Double(steps) * span / Double(Self.divisions)
        value = min(max(stepped, range.lowerBound), range.upperBound)
    }
}
