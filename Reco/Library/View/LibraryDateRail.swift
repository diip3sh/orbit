//
//  LibraryDateRail.swift
//  Reco
//

import SwiftUI

/// The Library's dates down the right edge, as a minimap of the grid's date headers: one short line per
/// date, the one at the top of the grid longer and brighter, its title shown beside the line under the
/// pointer, and a click that scrolls the grid to it.
///
/// Adapted from Chánh Đại's Line Nav (chanhdai.com/components/line-nav): a vertical stack of lines whose
/// marker expands on hover and for the active item. Only the lines take room, so the grid keeps nearly its
/// full width; the title floats to their left, over the grid, while pointed at.
struct LibraryDateRail: View {

    let groups: [LibraryDateGroup]

    /// The date at the top of the grid, by ``LibraryDateGroup/id``.
    let active: String?

    let onSelect: (String) -> Void

    /// What the grid keeps clear on its trailing side: the line column and the margin past it.
    static let width: CGFloat = LibraryDateRailDate.lineColumn + EditorTheme.spacing

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(groups) { group in
                LibraryDateRailDate(title: group.title, isActive: group.id == active) {
                    onSelect(group.id)
                }
            }
        }
        .padding(.trailing, EditorTheme.spacing)
        .frame(width: Self.width, alignment: .trailing)
    }
}

/// One date in the rail: its line, which lengthens when the date is at the top of the grid or under the
/// pointer, and its title to the left while pointed at.
private struct LibraryDateRailDate: View {

    let title: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    /// The line column, so a marked line grows leftward inside it, and the line at rest and marked.
    static let lineColumn: CGFloat = 28
    private static let lineWidth: CGFloat = 16
    private static let markedLineWidth: CGFloat = 28
    private static let lineHeight: CGFloat = 2

    /// Each date's row, which is also the gap between lines: tall enough to point at.
    private static let rowHeight: CGFloat = 10

    private var isMarked: Bool { isActive || isHovered }

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(isActive ? EditorTheme.ink : isHovered ? EditorTheme.dim : EditorTheme.faint)
                .frame(width: isMarked ? Self.markedLineWidth : Self.lineWidth, height: Self.lineHeight)
                .frame(width: Self.lineColumn, height: Self.rowHeight, alignment: .trailing)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .overlay(alignment: .trailing) {
            if isHovered {
                label
                    // Moved past the row by the line column and a gap, so it never covers the lines. An
                    // alignment guide inside the overlay was ignored: the title sat on its line and ran off
                    // the window's edge.
                    .offset(x: -(Self.lineColumn + EditorTheme.smallSpacing))
                    .transition(.opacity)
            }
        }
        // Above the rows after it, whose lines would otherwise draw over a tall title
        .zIndex(isHovered ? 1 : 0)
        .accessibilityLabel(title)
        .editorMotion(EditorTheme.quickMotion, value: isMarked)
        .editorMotion(EditorTheme.quickMotion, value: isActive)
    }

    /// The title alone, with no chip behind it.
    private var label: some View {
        Text(title)
            .font(.title3.weight(.medium))
            .foregroundStyle(EditorTheme.ink)
            .lineLimit(1)
            .fixedSize()
            .allowsHitTesting(false)
    }
}
