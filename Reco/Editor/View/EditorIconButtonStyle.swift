//
//  EditorIconButtonStyle.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A round icon button whose icon brightens from dim to ink under the pointer. The prominent one
/// is filled off-white, for the transport's play button. A press shrinks it a little.
struct EditorIconButtonStyle: ButtonStyle {
    var isProminent = false

    /// The circle's size, when not the usual 30 pt (38 prominent).
    var diameter: CGFloat?

    func makeBody(configuration: Configuration) -> some View {
        EditorIconButton(configuration: configuration, isProminent: isProminent, diameter: diameter)
    }
}

extension ButtonStyle where Self == EditorIconButtonStyle {
    static var editorIcon: Self { EditorIconButtonStyle() }
    static var editorProminentIcon: Self { EditorIconButtonStyle(isProminent: true) }
}

private struct EditorIconButton: View {
    let configuration: ButtonStyleConfiguration
    let isProminent: Bool
    let diameter: CGFloat?

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let size = diameter ?? (isProminent ? 38 : 30)

        configuration.label
            .labelStyle(.iconOnly)
            .imageScale(isProminent && diameter == nil ? .large : .medium)
            .foregroundStyle(isProminent ? EditorTheme.primaryInk : isLit ? EditorTheme.ink : EditorTheme.dim)
            .frame(width: size, height: size)
            .background(fill, in: .circle)
            .contentShape(.circle)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(isEnabled ? 1 : 0.35)
            .onHover { isHovered = $0 }
            .editorMotion(EditorTheme.quickMotion, value: isHovered)
            // The press shows on the frame it lands; only the release eases
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: configuration.isPressed)
    }

    private var isLit: Bool {
        isEnabled && (isHovered || configuration.isPressed)
    }

    /// The prominent button dims a little under the pointer; the others light up, more while pressed.
    private var fill: Color {
        if isProminent {
            return isLit ? EditorTheme.primaryHover : EditorTheme.primary
        }
        return .primary.opacity(isEnabled && configuration.isPressed ? 0.12 : isLit ? 0.06 : 0)
    }
}
