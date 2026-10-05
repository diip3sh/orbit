//
//  NotchMotion.swift
//  Reco
//

import SwiftUI

/// The notch shelf's feel, in one place (spec 0013). These numbers match notchi's measured behaviour, at the
/// user's request (2026-10-04): the springs overshoot a little on purpose, the one exception to the
/// bounce-free motion rule. Don't re-derive them.
nonisolated enum NotchMotion {

    // MARK: - Timing

    /// The pointer must stay on the shape this long before it opens; until then it only peeks
    static let openDelay = Duration.milliseconds(300)

    /// How long the pointer may be away before the open panel collapses; coming back cancels it
    static let closeDelay = Duration.milliseconds(500)

    // MARK: - Peek (the pointer is on the collapsed shape)

    /// The shape grows this much on each side, and downward
    static let peekGrowth = CGSize(width: 7.5, height: 5)
    static let peekShadowOpacity = 0.3

    static let peekIn = Animation.spring(response: 0.36, dampingFraction: 0.74)
    static let peekOut = Animation.spring(response: 0.28, dampingFraction: 0.96)

    // MARK: - Open

    static let expandedShadowOpacity = 0.7

    /// Both shadows are black with this blur; `NotchGeometry.windowRoom` leaves room for it
    static let shadowRadius: CGFloat = 6

    static let expand = Animation.spring(response: 0.5, dampingFraction: 0.78)
    static let collapse = Animation.spring(response: 0.36, dampingFraction: 0.88)

    // MARK: - Outline

    /// The ears where the top corners meet the menu bar (they curve inward), and the bottom corners
    static let collapsedTopRadius: CGFloat = 6
    static let expandedTopRadius: CGFloat = 19
    static let collapsedBottomRadius: CGFloat = 14
    static let expandedBottomRadius: CGFloat = 24

    // MARK: - Content

    /// The strip of screenshots rises in after the shape has started to open, and leaves first
    static var bodyTransition: AnyTransition {
        .asymmetric(
            insertion: .offset(y: -12).combined(with: .opacity).animation(.easeOut(duration: 0.22).delay(0.08)),
            removal: .offset(y: -6).combined(with: .opacity).animation(.easeIn(duration: 0.12))
        )
    }

    /// The header row follows the strip in, and leaves first of all
    static var headerTransition: AnyTransition {
        .asymmetric(
            insertion: .offset(y: -8).combined(with: .opacity).animation(.easeOut(duration: 0.2).delay(0.12)),
            removal: .offset(y: -4).combined(with: .opacity).animation(.easeIn(duration: 0.1))
        )
    }
}
