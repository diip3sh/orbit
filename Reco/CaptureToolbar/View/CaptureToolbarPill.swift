//
//  CaptureToolbarPill.swift
//  Reco
//

import SwiftUI

extension View {

    /// One of the toolbar's groups: dark Liquid Glass on macOS 26, tinted so the bar reads the same over
    /// any desktop, and answering a press; before, a dark material with a hairline. Solid with Reduce
    /// Transparency, with a defined edge with Increase Contrast.
    /// `isInteractive` false for a surface that holds controls rather than being pressed itself
    func captureToolbarPill(tint: Color = CaptureToolbarView.ground, isInteractive: Bool = true) -> some View {
        modifier(CaptureToolbarPill(tint: tint, isInteractive: isInteractive))
    }
}

private struct CaptureToolbarPill: ViewModifier {
    let tint: Color
    let isInteractive: Bool

    @Environment(\.accessibilityReduceTransparency) private var reducesTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    func body(content: Content) -> some View {
        surface(content.padding(4))
            .overlay {
                if contrast == .increased {
                    shape.strokeBorder(.white.opacity(0.5))
                }
            }
    }

    @ViewBuilder
    private func surface(_ content: some View) -> some View {
        if reducesTransparency {
            content.background(tint.opacity(1), in: shape)
        } else if #available(macOS 26, *) {
            content.glassEffect(.regular.tint(tint.opacity(0.6)).interactive(isInteractive), in: shape)
        } else {
            content
                .background(tint.opacity(0.75), in: shape)
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.1)))
        }
    }
}
