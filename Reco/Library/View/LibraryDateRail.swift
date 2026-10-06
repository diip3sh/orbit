//
//  LibraryDateRail.swift
//  Reco
//

import SwiftUI

/// The Library's dates down the right edge, as a minimap of the grid's date headers: every date with its
/// line, the one at the top of the grid marked with a longer, brighter line and a brighter title, and a
/// click that scrolls the grid to it.
///
/// Adapted from Chánh Đại's Line Nav (chanhdai.com/components/line-nav): a vertical list whose line
/// marker expands on hover and for the active item, and whose active item brightens. The lines sit in a
/// fixed column so the titles stay aligned as the markers grow; here the titles are the grid's date
/// headers rather than page names, and a click scrolls rather than navigates.
struct LibraryDateRail: View {

    let groups: [LibraryDateGroup]

    /// The date at the top of the grid, by ``LibraryDateGroup/id``.
    let active: String?

    let onSelect: (String) -> Void

    /// The line column, and the line at rest and marked. Room for the marked line, so a title doesn't
    /// move as its line grows.
    private static let lineColumn: CGFloat = 28
    private static let lineWidth: CGFloat = 18
    private static let markedLineWidth: CGFloat = 28
    private static let lineHeight: CGFloat = 2

    /// What the grid keeps clear on its trailing side, so the titles never sit on the last column: the
    /// line column, the longest header (a month and a year) and the margin past them.
    static let width: CGFloat = 152

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            ForEach(groups) { group in
                LibraryDateRailDate(title: group.title, isActive: group.id == active) {
                    onSelect(group.id)
                }
            }
        }
        .padding(.trailing, EditorTheme.spacing)
        .frame(width: Self.width, alignment: .leading)
    }
}

/// One date in the rail: its line, which lengthens and darkens when the date is at the top of the grid or
/// under the pointer, and its title, which brightens with it.
private struct LibraryDateRailDate: View {

    let title: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    /// The line column, and the line at rest and marked. Room for the marked line, so a title doesn't
    /// move as its line grows.
    private static let lineColumn: CGFloat = 28
    private static let lineWidth: CGFloat = 18
    private static let markedLineWidth: CGFloat = 28
    private static let lineHeight: CGFloat = 2

    /// Whether the date is being pointed at or read.
    private var isMarked: Bool { isActive || isHovered }

    var body: some View {
        Button(action: action) {
            HStack(spacing: EditorTheme.smallSpacing) {
                // Trailing inside its column, so the line grows leftward and the titles stay put
                Capsule()
                    .fill(isActive ? EditorTheme.ink : EditorTheme.faint)
                    .frame(
                        width: isMarked ? Self.markedLineWidth : Self.lineWidth,
                        height: Self.lineHeight
                    )
                    .frame(width: Self.lineColumn, alignment: .trailing)
                Text(title)
                    .font(.callout)
                    .foregroundStyle(isActive ? EditorTheme.ink : EditorTheme.dim)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.vertical, EditorTheme.tightSpacing)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(title)
        .accessibilityLabel(title)
        .editorMotion(EditorTheme.quickMotion, value: isMarked)
        .editorMotion(EditorTheme.quickMotion, value: isActive)
    }
}
