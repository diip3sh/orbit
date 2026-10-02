//
//  MaterializeTransition.swift
//  Reco
//

import SwiftUI

/// A surface arriving like a material: it sharpens, settles from 0.98 and fades in, `offset` points
/// from where it rests, and leaves the same way. Opacity alone with Reduce Motion. Only for SwiftUI
/// content: AppKit controls and the player aren't blurred.
struct MaterializeTransition: Transition {
    var offset: CGFloat = 0

    func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(Materialized(isSettled: phase.isIdentity, offset: offset))
    }
}

extension Transition where Self == MaterializeTransition {
    static var materialize: Self { MaterializeTransition() }

    static func materialize(offset: CGFloat) -> Self {
        MaterializeTransition(offset: offset)
    }
}

private struct Materialized: ViewModifier {
    let isSettled: Bool
    let offset: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    func body(content: Content) -> some View {
        let isStill = isSettled || reducesMotion

        content
            .blur(radius: isStill ? 0 : 6)
            .scaleEffect(isStill ? 1 : 0.98)
            .offset(y: isStill ? 0 : offset)
            .opacity(isSettled ? 1 : 0)
    }
}
