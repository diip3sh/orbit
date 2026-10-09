//
//  View+EditorSurface.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import AppKit
import SwiftUI

extension View {

    /// A solid surface in `shape`: `fill` with a hairline edge (the hairline's colour set is stronger with Increase
    /// Contrast). `floats` adds the token scale's floating shadow (xl: 32 px blur, 4 px down), for a panel over the
    /// desktop or a window; its window needs 20 pt of room around the shape or the shadow is clipped.
    func editorSurface(
        in shape: some InsettableShape,
        fill: Color = EditorTheme.surface,
        floats: Bool = false
    ) -> some View {
        modifier(EditorSurface(shape: shape, fill: fill, floats: floats))
    }

    /// Reco's accent and typeface for everything under a window's root, native controls included.
    func themed() -> some View {
        tint(EditorTheme.accent)
            .font(.theme())
    }

    /// The window's ground: the system's window colour, solid, with ink text.
    func editorWindowBackground() -> some View {
        foregroundStyle(EditorTheme.ink)
            // Solid, as a document window: see-through, it read as an overlay over the apps behind it
            .background {
                EditorTheme.stage
                    .ignoresSafeArea()
            }
    }

    /// `animation` for changes of `value`, or none with Reduce Motion on (or when `animation` is nil).
    func editorMotion(_ animation: Animation? = EditorTheme.motion, value: some Equatable) -> some View {
        modifier(EditorMotion(animation: animation, value: value))
    }
}

private struct EditorSurface<SurfaceShape: InsettableShape>: ViewModifier {
    let shape: SurfaceShape
    let fill: Color
    let floats: Bool

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                shape.fill(fill)
                    .shadow(color: floats ? shadow : .clear, radius: 16, y: 4)
            }
            .overlay(shape.strokeBorder(EditorTheme.hairline))
    }

    /// The token's `rgba(8, 9, 10, 0.6)`; on light surfaces that much reads as a smudge, so a quarter of it.
    private var shadow: Color {
        Color(red: 8 / 255, green: 9 / 255, blue: 10 / 255).opacity(colorScheme == .dark ? 0.6 : 0.15)
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
