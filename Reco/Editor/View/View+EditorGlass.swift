//
//  View+EditorGlass.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import AppKit
import SwiftUI

extension View {

    /// Liquid Glass in `shape` on macOS 26; before, a material with a hairline edge. With Reduce
    /// Transparency on, the stage's solid ground with the hairline.
    func editorGlass(in shape: some Shape) -> some View {
        modifier(EditorGlass(shape: shape))
    }

    /// The window's ground: the desktop frosted through at the shell's 80%, in ink.
    func editorWindowBackground() -> some View {
        foregroundStyle(EditorTheme.ink)
            .background {
                EditorTheme.stage.opacity(0.6)
                    .background(EditorBackdrop())
                    .ignoresSafeArea()
            }
    }

    /// `animation` for changes of `value`, or none with Reduce Motion on (or when `animation` is nil).
    func editorMotion(_ animation: Animation? = EditorTheme.motion, value: some Equatable) -> some View {
        modifier(EditorMotion(animation: animation, value: value))
    }
}

private struct EditorGlass<GlassShape: Shape>: ViewModifier {
    let shape: GlassShape

    @Environment(\.accessibilityReduceTransparency) private var reducesTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        surface(content)
            .overlay {
                // Increase Contrast: a defined edge on every surface
                if contrast == .increased {
                    shape.stroke(EditorTheme.dim)
                }
            }
    }

    @ViewBuilder
    private func surface(_ content: Content) -> some View {
        if reducesTransparency {
            content
                .background(EditorTheme.stage, in: shape)
                .overlay(shape.stroke(EditorTheme.hairline))
        } else if #available(macOS 26, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.stroke(EditorTheme.hairline))
        }
    }
}

private struct EditorMotion<Value: Equatable>: ViewModifier {
    let animation: Animation?
    let value: Value

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    func body(content: Content) -> some View {
        content.animation(reducesMotion ? nil : animation, value: value)
    }
}

/// Runs `body` animated by `animation`, or without animation with Reduce Motion on. For code
/// with no view environment to read it from.
func withMotion<Result>(
    _ animation: Animation = EditorTheme.motion,
    _ body: () throws -> Result
) rethrows -> Result {
    try withAnimation(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : animation, body)
}

extension ToolbarContent {

    /// Without the glass macOS 26 puts behind toolbar items, for a button that draws its own.
    @ToolbarContentBuilder
    func hidingSharedBackground() -> some ToolbarContent {
        if #available(macOS 26, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
    }
}
