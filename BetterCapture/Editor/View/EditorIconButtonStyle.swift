//
//  EditorIconButtonStyle.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A round icon button that lights up under the pointer. The prominent one is filled with the
/// accent, for the transport's play button.
struct EditorIconButtonStyle: ButtonStyle {
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        EditorIconButton(configuration: configuration, isProminent: isProminent)
    }
}

extension ButtonStyle where Self == EditorIconButtonStyle {
    static var editorIcon: Self { EditorIconButtonStyle() }
    static var editorProminentIcon: Self { EditorIconButtonStyle(isProminent: true) }
}

private struct EditorIconButton: View {
    let configuration: ButtonStyleConfiguration
    let isProminent: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let size: CGFloat = isProminent ? 38 : 30

        configuration.label
            .labelStyle(.iconOnly)
            .imageScale(isProminent ? .large : .medium)
            .foregroundStyle(isProminent ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(isProminent ? AnyShapeStyle(EditorTheme.accent) : AnyShapeStyle(.white.opacity(highlight)))
                    .brightness(isProminent ? highlight : 0)
            }
            .contentShape(.circle)
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .onHover { isHovered = $0 }
            .editorMotion(.snappy(duration: 0.18), value: isHovered)
            .editorMotion(.snappy(duration: 0.18), value: configuration.isPressed)
    }

    /// How much lighter the button is, for hover and press.
    private var highlight: Double {
        guard isEnabled else { return 0 }
        return configuration.isPressed ? 0.16 : isHovered ? 0.09 : 0
    }
}
