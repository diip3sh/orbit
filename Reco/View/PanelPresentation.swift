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
    /// cross-fade only.
    func panelPresentation(isPresented: Bool, anchor: UnitPoint) -> some View {
        modifier(PanelPresentation(isPresented: isPresented, anchor: anchor))
    }
}

struct PanelPresentation: ViewModifier {

    /// How long a panel stays after `isPresented` turns false: its exit spring has settled.
    nonisolated static let exitDelay = Duration.milliseconds(350)

    let isPresented: Bool
    let anchor: UnitPoint

    // Shown only once the view is on screen, so the entrance animates from hidden
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    func body(content: Content) -> some View {
        let isShown = hasAppeared && isPresented

        content
            .opacity(isShown ? 1 : 0)
            .scaleEffect(isShown || reducesMotion ? 1 : 0.96, anchor: anchor)
            .animation(reducesMotion ? EditorTheme.fadeMotion : EditorTheme.motion, value: isShown)
            .onAppear { hasAppeared = true }
    }
}
