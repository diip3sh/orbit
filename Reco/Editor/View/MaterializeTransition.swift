//
//  MaterializeTransition.swift
//  Reco
//

import SwiftUI

/// A surface arriving like a material: it sharpens, settles from 0.98 and fades in, `offset` points
/// below or beside where it rests, and leaves the same way. Opacity alone with Reduce Motion. Only for SwiftUI
/// content: AppKit controls and the player aren't blurred.
struct MaterializeTransition: Transition {
    var offset: CGFloat = 0

    /// Points to the side of where it rests.
    var sideways: CGFloat = 0

    func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(Materialized(isSettled: phase.isIdentity, offset: CGSize(width: sideways, height: offset)))
    }
}

extension Transition where Self == MaterializeTransition {
    static var materialize: Self { MaterializeTransition() }

    static func materialize(offset: CGFloat) -> Self {
        MaterializeTransition(offset: offset)
    }

    static func materialize(sideways: CGFloat) -> Self {
        MaterializeTransition(sideways: sideways)
    }
}

private struct Materialized: ViewModifier {
    let isSettled: Bool
    let offset: CGSize

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    func body(content: Content) -> some View {
        let isStill = isSettled || reducesMotion

        content
            .blur(radius: isStill ? 0 : 6)
            .scaleEffect(isStill ? 1 : 0.98)
            .offset(isStill ? .zero : offset)
            .opacity(isSettled ? 1 : 0)
    }
}
