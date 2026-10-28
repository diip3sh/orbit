//
//  View+HeaderCapsule.swift
//  Reco
//

import SwiftUI

/// The pill controls in a window's header row: the Library's search, Filter and New, the editor's Style and Export.
extension View {

    /// The header's 36 pt capsule: a faint fill and edge, or the given ones.
    func headerCapsule(fill: Color = EditorTheme.ink.opacity(0.06), stroke: Color = EditorTheme.ink.opacity(0.14)) -> some View {
        frame(height: 36)
            .background(fill, in: .capsule)
            .overlay(Capsule().strokeBorder(stroke))
            .contentShape(.capsule)
    }

    /// The accent capsule of the header's primary control.
    func headerProminentCapsule() -> some View {
        headerCapsule(fill: EditorTheme.accentFill.opacity(0.88), stroke: EditorTheme.ink.opacity(0.25))
    }

    /// A menu drawn only by its label: AppKit's pop-up button would add its own bezel and indicator.
    func headerMenuStyle() -> some View {
        menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
    }
}
