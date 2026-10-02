//
//  EditorSlider.swift
//  Reco
//

import SwiftUI

/// The editor's slider: a 6 pt track filled in ink up to a white pill. The pill follows the pointer
/// from where it was grabbed and grows while held; a press on the track springs it there. The
/// track brightens under the pointer.
struct EditorSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    @State private var width: CGFloat = 0
    @State private var isHovered = false

    /// How far from the knob's centre it was grabbed, while it's dragged.
    @State private var grabOffset: CGFloat?

    private static let knobSize = CGSize(width: 22, height: 14)
    private static let trackHeight: CGFloat = 6

    var body: some View {
        // The knob's centre travels between half a knob from each end
        let travel = max(width - Self.knobSize.width, 0)
        let length = range.upperBound - range.lowerBound
        let fraction = length > 0 ? (value - range.lowerBound) / length : 0
        let center = Self.knobSize.width / 2 + travel * fraction
        let isHeld = grabOffset != nil

        ZStack(alignment: .leading) {
            Capsule()
                .fill(.primary.opacity(isHovered || isHeld ? 0.2 : 0.12))
                .frame(height: Self.trackHeight)
            Capsule()
                .fill(EditorTheme.ink.opacity(isHovered || isHeld ? 1 : 0.85))
                .frame(width: center, height: Self.trackHeight)
            Capsule()
                .fill(.white)
                .shadow(color: .black.opacity(0.12), radius: 0.5)
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1.5)
                .frame(width: Self.knobSize.width, height: Self.knobSize.height)
                .scaleEffect(isHeld ? 1.18 : 1)
                .offset(x: center - Self.knobSize.width / 2)
        }
        .frame(maxWidth: .infinity, minHeight: 20, maxHeight: 20)
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    guard travel > 0 else { return }
                    let position = { (offset: CGFloat) in
                        range.lowerBound + min(max((drag.location.x - offset - Self.knobSize.width / 2) / travel, 0), 1) * length
                    }
                    if let grabOffset {
                        value = position(grabOffset)
                        return
                    }
                    let fromKnob = drag.startLocation.x - center
                    if abs(fromKnob) <= Self.knobSize.width / 2 {
                        grabOffset = fromKnob
                    } else {
                        // A press on the track: the knob springs there, then follows
                        grabOffset = 0
                        withMotion {
                            value = position(0)
                        }
                    }
                }
                .onEnded { _ in
                    grabOffset = nil
                }
        )
        .onHover { isHovered = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .editorMotion(EditorTheme.quickMotion, value: isHovered)
        // The press shows on the frame it lands; only the release eases
        .editorMotion(isHeld ? nil : EditorTheme.slideMotion, value: isHeld)
        .accessibilityRepresentation {
            Slider(value: $value, in: range)
        }
    }
}
