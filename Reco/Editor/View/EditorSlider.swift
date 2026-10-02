//
//  EditorSlider.swift
//  Reco
//

import SwiftUI

/// The editor's slider: a thin track filled in ink up to a white knob. The knob follows the pointer
/// from where it was grabbed and grows a little while held; a press on the track brings it there.
struct EditorSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    @Environment(\.isEnabled) private var isEnabled
    @State private var width: CGFloat = 0

    /// How far from the knob's centre it was grabbed, while it's dragged.
    @State private var grabOffset: CGFloat?

    private static let knobSize: CGFloat = 16
    private static let trackHeight: CGFloat = 4

    var body: some View {
        // The knob's centre travels between half a knob from each end
        let travel = max(width - Self.knobSize, 0)
        let length = range.upperBound - range.lowerBound
        let fraction = length > 0 ? (value - range.lowerBound) / length : 0
        let center = Self.knobSize / 2 + travel * fraction

        ZStack(alignment: .leading) {
            Capsule()
                .fill(.primary.opacity(0.12))
                .frame(height: Self.trackHeight)
            Capsule()
                .fill(EditorTheme.ink)
                .frame(width: center, height: Self.trackHeight)
            Circle()
                .fill(.white)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                .frame(width: Self.knobSize, height: Self.knobSize)
                .scaleEffect(grabOffset == nil ? 1 : 1.2)
                .offset(x: center - Self.knobSize / 2)
        }
        .frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20)
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    let offset: CGFloat
                    if let grabOffset {
                        offset = grabOffset
                    } else {
                        let fromKnob = drag.startLocation.x - center
                        offset = abs(fromKnob) <= Self.knobSize / 2 ? fromKnob : 0
                        grabOffset = offset
                    }
                    guard travel > 0 else { return }
                    let position = min(max((drag.location.x - offset - Self.knobSize / 2) / travel, 0), 1)
                    value = range.lowerBound + position * length
                }
                .onEnded { _ in
                    grabOffset = nil
                }
        )
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        // The press shows on the frame it lands; only the release eases
        .editorMotion(grabOffset == nil ? EditorTheme.quickMotion : nil, value: grabOffset == nil)
        .accessibilityRepresentation {
            Slider(value: $value, in: range)
        }
    }
}
