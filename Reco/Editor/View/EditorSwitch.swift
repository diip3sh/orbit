//
//  EditorSwitch.swift
//  Reco
//

import SwiftUI

/// The editor's switch, drawn only: a track that fills with ink when on and a knob that springs
/// across it, stretching towards where it will go while pressed.
struct EditorSwitch: View {
    let isOn: Bool
    let isPressed: Bool

    private static let size = CGSize(width: 34, height: 20)
    private static let inset: CGFloat = 2
    private static let knobSize: CGFloat = 16
    private static let pressedKnobWidth: CGFloat = 21

    var body: some View {
        let knobWidth = isPressed ? Self.pressedKnobWidth : Self.knobSize
        let travel = Self.size.width - Self.inset * 2 - knobWidth

        ZStack(alignment: .leading) {
            Capsule()
                .fill(.primary.opacity(0.16))
            Capsule()
                .fill(EditorTheme.ink)
                .opacity(isOn ? 1 : 0)
            // White on the empty track, the ground's color on the ink one
            Capsule()
                .fill(.white)
                .overlay {
                    Capsule()
                        .fill(EditorTheme.primaryInk)
                        .opacity(isOn ? 1 : 0)
                }
                .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                .frame(width: knobWidth, height: Self.knobSize)
                .offset(x: Self.inset + (isOn ? travel : 0))
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .editorMotion(EditorTheme.slideMotion, value: isOn)
        // The knob's stretch eases both ways: a jump in its width reads as a stutter before the slide
        .editorMotion(EditorTheme.quickMotion, value: isPressed)
    }
}
