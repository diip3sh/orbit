//
//  MenuRowButtonStyle.swift
//  Reco
//

import SwiftUI

/// The fill behind a hovered popover row, as Control Center's: the row's full height, inset from the
/// popover's edge, with soft corners that follow its rounded ones.
struct MenuRowHighlight: View {
    let opacity: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(EditorTheme.ink.opacity(opacity))
            .padding(.horizontal, 6)
    }
}

/// A row of the menu bar popover: a `MenuRowHighlight` that steps to a
/// light tone under the pointer and a stronger one the moment it's pressed. Only the press lands
/// at once; hover and release ease. Disabled rows dim and don't react.
struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MenuRow(configuration: configuration)
    }
}

extension ButtonStyle where Self == MenuRowButtonStyle {
    static var menuRow: Self { MenuRowButtonStyle() }
}

private struct MenuRow: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .contentShape(.rect)
            .background { MenuRowHighlight(opacity: fill) }
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { isHovered = $0 }
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: fill)
    }

    private var fill: Double {
        guard isEnabled else { return 0 }
        return configuration.isPressed ? 0.16 : isHovered ? 0.1 : 0
    }
}
