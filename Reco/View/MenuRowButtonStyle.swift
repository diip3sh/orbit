//
//  MenuRowButtonStyle.swift
//  Reco
//

import SwiftUI

/// A row of the menu bar popover: a rounded fill, inset 4 pt from the edges, that steps to a
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
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(fill))
                    .padding(.horizontal, 4)
            }
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { isHovered = $0 }
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: fill)
    }

    private var fill: Double {
        guard isEnabled else { return 0 }
        return configuration.isPressed ? 0.14 : isHovered ? 0.08 : 0
    }
}
