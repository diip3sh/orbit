//
//  CaptureToolbarButtonStyle.swift
//  Reco
//

import SwiftUI

/// A control on the capture toolbar: dim at rest, a fill that steps up under the pointer and the moment
/// it's pressed. `isOn` makes it a switch: on is filled with the accent, off sits on a
/// faint fill of its own so it still reads as a switch. Only the press lands at once; hover and release ease.
struct CaptureToolbarButtonStyle: ButtonStyle {
    var isOn: Bool?
    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        CaptureToolbarButton(configuration: configuration, isOn: isOn, isSelected: isSelected)
    }
}

/// The toolbar's action, Capture or Record, on its live-tinted pill.
struct CaptureToolbarActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CaptureToolbarActionButton(configuration: configuration)
    }
}

extension ButtonStyle where Self == CaptureToolbarButtonStyle {
    static var captureToolbar: Self { CaptureToolbarButtonStyle() }

    static func captureToolbar(isOn: Bool? = nil, isSelected: Bool = false) -> Self {
        CaptureToolbarButtonStyle(isOn: isOn, isSelected: isSelected)
    }
}

extension ButtonStyle where Self == CaptureToolbarActionButtonStyle {
    static var captureToolbarAction: Self { CaptureToolbarActionButtonStyle() }
}

private struct CaptureToolbarButton: View {
    let configuration: ButtonStyleConfiguration
    let isOn: Bool?
    let isSelected: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        configuration.label
            .foregroundStyle(foreground)
            .padding(.horizontal, EditorTheme.smallSpacing)
            .frame(minWidth: 36, minHeight: 36)
            .contentShape(shape)
            .background(fill, in: shape)
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { isHovered = $0 }
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: isLit)
    }

    private var isLit: Bool {
        isEnabled && (isHovered || configuration.isPressed)
    }

    private var foreground: Color {
        // A selected mode sits on the live highlight its group draws behind it
        if isOn == true || isSelected { return EditorTheme.onAccent }
        return isLit ? EditorTheme.ink : EditorTheme.dim
    }

    private var fill: Color {
        if isOn == true {
            return CaptureToolbarView.live.opacity(configuration.isPressed ? 0.7 : isHovered ? 0.9 : 1)
        }
        guard isEnabled else { return .clear }
        let rest = isOn == false ? 0.06 : 0
        return EditorTheme.ink.opacity(configuration.isPressed ? 0.14 : isHovered ? 0.1 : rest)
    }
}

private struct CaptureToolbarActionButton: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.theme(.body, weight: .semibold))
            .foregroundStyle(EditorTheme.onAccent)
            .padding(.horizontal, EditorTheme.mediumSpacing + EditorTheme.tightSpacing)
            .frame(minHeight: 36)
            .contentShape(.rect(cornerRadius: 12, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}
