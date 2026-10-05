//
//  PanelPresentation.swift
//  Reco
//

import SwiftUI

extension View {

    /// Arrives and leaves the same way. With `blur` it pops in where it is, from out of focus, with no
    /// direction at all; without it, it fades and settles from slightly smaller, anchored at `anchor`.
    /// The window orders itself out `PanelPresentation.exitDelay` after `isPresented` turns false. A
    /// spring without bounce, so a change during the move turns round from where the panel is; with
    /// Reduce Motion, a short cross-fade only. `motion` replaces the panel spring for a surface that
    /// should arrive faster.
    func panelPresentation(isPresented: Bool, anchor: UnitPoint, motion: Animation? = nil, blur: CGFloat = 0) -> some View {
        modifier(PanelPresentation(isPresented: isPresented, anchor: anchor, motion: motion, blur: blur))
    }
}

struct PanelPresentation: ViewModifier {

    /// How long a panel stays after `isPresented` turns false: its exit spring has settled.
    nonisolated static let exitDelay = Duration.milliseconds(350)

    let isPresented: Bool
    let anchor: UnitPoint
    let motion: Animation?
    /// How out of focus the panel starts, in points; 0 scales instead
    let blur: CGFloat

    // Shown only once the view is on screen, so the entrance animates from hidden
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    func body(content: Content) -> some View {
        let isShown = hasAppeared && isPresented
        let arrival = reducesMotion ? EditorTheme.fadeMotion : (motion ?? EditorTheme.motion)
        // A blur has no direction; a scale does, since the corner furthest from its anchor travels most
        let scale = isShown || reducesMotion || blur > 0 ? 1 : 0.96
        let radius = isShown || reducesMotion ? 0 : blur

        // Scoped to these modifiers only. As a panel appears its window is sized and its content
        // re-centred in the same update, and an animation on the whole view slid that move in too:
        // the capture toolbar arrived diagonally whatever its own entrance was.
        content
            .animation(arrival) { view in
                view
                    .opacity(isShown ? 1 : 0)
                    .blur(radius: radius)
                    .scaleEffect(scale, anchor: anchor)
            }
            .onAppear { hasAppeared = true }
    }
}
