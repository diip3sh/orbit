//
//  View+EditorGlass.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

extension View {

    /// Liquid Glass in `shape` on macOS 26; before, a material with a hairline edge.
    @ViewBuilder
    func editorGlass(in shape: some Shape) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.stroke(EditorTheme.hairline))
        }
    }

    /// The window's one main action: tinted glass on macOS 26, a filled button before.
    @ViewBuilder
    func prominentEditorButton() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    /// `animation` for changes of `value`, or none with Reduce Motion on.
    func editorMotion(_ animation: Animation = EditorTheme.motion, value: some Equatable) -> some View {
        modifier(EditorMotion(animation: animation, value: value))
    }
}

private struct EditorMotion<Value: Equatable>: ViewModifier {
    let animation: Animation
    let value: Value

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    func body(content: Content) -> some View {
        content.animation(reducesMotion ? nil : animation, value: value)
    }
}
