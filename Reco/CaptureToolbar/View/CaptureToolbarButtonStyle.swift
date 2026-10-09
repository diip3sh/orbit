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

/// The toolbar's action, Capture or Record, as its own live pill.
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
            .captureToolbarLive(
                isOn == true, in: shape, isInteractive: isEnabled,
                fillOpacity: configuration.isPressed ? 0.7 : isLit ? 0.9 : 1
            )
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

    /// Off and plain controls only: on is the live surface, which steps its own fill (`fillOpacity`)
    private var fill: Color {
        guard isOn != true, isEnabled else { return .clear }
        let rest = isOn == false ? 0.06 : 0
        return EditorTheme.ink.opacity(configuration.isPressed ? 0.14 : isHovered ? 0.1 : rest)
    }
}

private struct CaptureToolbarActionButton: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let label = configuration.label
            .font(.theme(.body, weight: .semibold))
            .foregroundStyle(isEnabled ? EditorTheme.onAccent : EditorTheme.dim)
            .padding(.horizontal, EditorTheme.mediumSpacing + EditorTheme.tightSpacing)
            .frame(minHeight: 36)

        if isEnabled {
            label
                .opacity(configuration.isPressed ? 0.7 : 1)
                // The pill's inset, as `captureToolbarPill`, so it lines up with the groups beside it
                .padding(4)
                .contentShape(shape)
                .captureToolbarLive(in: shape, isInteractive: true)
        } else {
            // Not live until it can run: a faded label on the accent read as a broken action
            label.captureToolbarPill()
        }
    }
}
