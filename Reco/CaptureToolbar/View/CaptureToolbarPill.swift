//
//  CaptureToolbarPill.swift
//  Reco
//

import SwiftUI

extension View {

    /// One of the toolbar's groups: a solid surface with a hairline edge. No shadow: the bar's window
    /// leaves only `CaptureToolbarView.margin` around it, less than the floating shadow needs.
    func captureToolbarPill(tint: Color = CaptureToolbarView.ground) -> some View {
        padding(4)
            .editorSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous), fill: tint)
    }

    /// What is live, chosen or on (`isLive`): on macOS 26, while the bar is key, Liquid Glass tinted with
    /// `CaptureToolbarView.live`; otherwise the solid fill. One modifier for the action, the mode's highlight
    /// and the switches at their own sizes. `fillOpacity` is the solid fill's hover and press, which interactive
    /// glass shows by itself.
    func captureToolbarLive(
        _ isLive: Bool = true, in shape: some Shape, isInteractive: Bool = false, fillOpacity: Double = 1
    ) -> some View {
        modifier(CaptureToolbarLiveSurface(isLive: isLive, shape: shape, isInteractive: isInteractive, fillOpacity: fillOpacity))
    }
}

private struct CaptureToolbarLiveSurface<S: Shape>: ViewModifier {
    /// How much of the accent the glass takes: at 1 it read as a solid fill over a dark desktop, at 0.5 the
    /// `onAccent` text sank into the dark behind it (captured 2026-10-09, macOS 27)
    static var tintOpacity: Double { 0.7 }

    let isLive: Bool
    let shape: S
    let isInteractive: Bool
    let fillOpacity: Double

    @Environment(\.controlActiveState) private var activeState
    @Environment(\.accessibilityReduceTransparency) private var reducesTransparency

    private var fill: Color {
        isLive ? CaptureToolbarView.live.opacity(fillOpacity) : .clear
    }

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            // Glass drops its tint while its window isn't key, plain and prominent alike, and setting
            // `controlActiveState` doesn't bring it back (same capture). The bar loses key to the area overlay
            // or a click in another app, and the solid fill keeps the accent then.
            let isGlass = activeState == .key && !reducesTransparency
            content
                .background(isGlass ? .clear : fill, in: shape)
                .glassEffect(
                    isLive && isGlass
                        ? .regular.tint(CaptureToolbarView.live.opacity(Self.tintOpacity)).interactive(isInteractive)
                        : .identity,
                    in: shape
                )
                // Comes and goes with the bar's own entrance, without glass's grow on top
                .glassEffectTransition(.identity)
        } else {
            content.background(fill, in: shape)
        }
    }
}
