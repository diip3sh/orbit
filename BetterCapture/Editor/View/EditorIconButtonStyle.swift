//
//  EditorIconButtonStyle.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A round icon button that lights up under the pointer. The prominent one is filled white, for
/// the transport's play button.
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
            .foregroundStyle(isProminent ? AnyShapeStyle(EditorTheme.stage) : AnyShapeStyle(.primary))
            .frame(width: size, height: size)
            .background(.white.opacity(fillOpacity), in: .circle)
            .contentShape(.circle)
            .opacity(isEnabled ? 1 : 0.35)
            .onHover { isHovered = $0 }
            .editorMotion(.snappy(duration: 0.18), value: isHovered)
            .editorMotion(.snappy(duration: 0.18), value: configuration.isPressed)
    }

    /// Lighter under the pointer; the prominent button dims while pressed, the others light up more.
    private var fillOpacity: Double {
        let isPressed = isEnabled && configuration.isPressed
        let isLit = isEnabled && isHovered
        if isProminent {
            return isPressed ? 0.75 : isLit ? 1 : 0.9
        }
        return isPressed ? 0.16 : isLit ? 0.09 : 0
    }
}
