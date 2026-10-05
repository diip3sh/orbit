//
//  PanelPresentation.swift
//  Reco
//

import SwiftUI

extension View {

    /// Arrives and leaves the same way: fades and settles from slightly smaller, anchored at the
    /// source it came from (`anchor`), and goes back there. The window orders itself out
    /// `PanelPresentation.exitDelay` after `isPresented` turns false. A spring without bounce, so
    /// a change during the move turns round from where the panel is; with Reduce Motion, a short
    /// cross-fade only. `motion` replaces the panel spring for a surface that should arrive faster.
    func panelPresentation(isPresented: Bool, anchor: UnitPoint, motion: Animation? = nil) -> some View {
        modifier(PanelPresentation(isPresented: isPresented, anchor: anchor, motion: motion))
    }
}

struct PanelPresentation: ViewModifier {

    /// How long a panel stays after `isPresented` turns false: its exit spring has settled.
    nonisolated static let exitDelay = Duration.milliseconds(350)

    let isPresented: Bool
    let anchor: UnitPoint
    let motion: Animation?

    // Shown only once the view is on screen, so the entrance animates from hidden
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    func body(content: Content) -> some View {
        let isShown = hasAppeared && isPresented
        let arrival = reducesMotion ? EditorTheme.fadeMotion : (motion ?? EditorTheme.motion)

        content
            .opacity(isShown ? 1 : 0)
            .scaleEffect(isShown || reducesMotion ? 1 : 0.96, anchor: anchor)
            .animation(arrival, value: isShown)
            .onAppear { hasAppeared = true }
    }
}
