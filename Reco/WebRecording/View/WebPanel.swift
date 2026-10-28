//
//  WebPanel.swift
//  Reco
//

import SwiftUI

/// The Web Recording window's panels (the agent, the stage with its timeline, the inspector) float apart on the
/// blurred desktop, with what their controls share: pills, round buttons and capsule fields on a faint ink fill.
enum WebPanel {

    /// Between the panels, and around them in the window, so their corners sit concentric with its own.
    static let gap: CGFloat = 8

    static let radius: CGFloat = 16

    static let padding: CGFloat = 16

    /// From a panel's top to the middle of its header row. The window's buttons stay where AppKit puts them
    /// beside a unified toolbar (centred 26 pt down, 19 pt in, measured on macOS 27) and resetting them on every
    /// resize was turned down, so the agent panel's header leaves them room on its left.
    static let headerHeight: CGFloat = 60

    /// The window's buttons' right edge, from the window's left (19 pt in, three 14 pt buttons 6 pt apart).
    static let windowButtonsWidth: CGFloat = 73

    /// A control's faint fill on a panel and its edge, a step over the hairline.
    static let fill = EditorTheme.ink.opacity(0.06)
    static let edge = EditorTheme.ink.opacity(0.12)
}

extension View {

    /// A panel of the window: solid (the stage and timeline, which hold the page) or the panel colour at 30% over the
    /// blurred desktop (the agent and the inspector).
    func webPanel(solid: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: WebPanel.radius, style: .continuous)
        return background(solid ? EditorTheme.panel : EditorTheme.panel.opacity(0.3), in: shape)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(EditorTheme.hairline)
            }
    }

    /// A capsule field's or control's faint fill and edge.
    func webField<S: InsettableShape>(in shape: S = Capsule()) -> some View {
        background(WebPanel.fill, in: shape)
            .overlay {
                shape.strokeBorder(WebPanel.edge)
            }
    }

    /// Drags the window from the empty parts of a header, as a title bar would: the window's title bar is hidden
    /// so the panels can reach its top.
    func dragsWindow() -> some View {
        background {
            Color.clear
                .contentShape(.rect)
                .gesture(WindowDragGesture())
                .allowsWindowActivationEvents(true)
        }
    }
}

/// A small capsule button on the faint fill: New take, Pick, the viewport and model menus, suggestions.
struct WebPillButtonStyle: ButtonStyle {
    var height: CGFloat = 28

    func makeBody(configuration: Configuration) -> some View {
        WebPill(configuration: configuration, height: height)
    }
}

extension ButtonStyle where Self == WebPillButtonStyle {
    static var webPill: Self { WebPillButtonStyle() }
}

private struct WebPill: View {
    let configuration: ButtonStyleConfiguration
    let height: CGFloat

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let lit = isEnabled && configuration.isPressed ? 0.08 : isEnabled && isHovered ? 0.04 : 0
        configuration.label
            .labelStyle(WebPillLabelStyle())
            .font(.theme(.callout, weight: .medium))
            .foregroundStyle(EditorTheme.ink)
            .lineLimit(1)
            .padding(.horizontal, EditorTheme.mediumSpacing)
            .frame(height: height)
            .background(EditorTheme.ink.opacity(lit), in: .capsule)
            .webField()
            .contentShape(.capsule)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.97 : 1)
            .onHover { isHovered = $0 }
            .editorMotion(EditorTheme.quickMotion, value: isHovered)
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: configuration.isPressed)
    }
}

private struct WebPillLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
                .foregroundStyle(EditorTheme.dim)
            configuration.title
        }
    }
}

/// The play button: an ink disc with the icon in the stage colour, dimming a little under the pointer.
struct WebInkCircleButtonStyle: ButtonStyle {
    var diameter: CGFloat = 40

    func makeBody(configuration: Configuration) -> some View {
        WebInkCircle(configuration: configuration, diameter: diameter)
    }
}

private struct WebInkCircle: View {
    let configuration: ButtonStyleConfiguration
    let diameter: CGFloat

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(EditorTheme.stage)
            .frame(width: diameter, height: diameter)
            .background(EditorTheme.ink.opacity(isEnabled && (isHovered || configuration.isPressed) ? 0.85 : 1), in: .circle)
            .contentShape(.circle)
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.94 : 1)
            .onHover { isHovered = $0 }
            .editorMotion(EditorTheme.quickMotion, value: isHovered)
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: configuration.isPressed)
    }
}

/// A small label over a control in the inspector ("Action", "Target"), with an optional value on the right.
struct WebFieldTitle<Trailing: View>: View {
    let title: LocalizedStringKey
    let trailing: Trailing

    init(_ title: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(EditorTheme.dim)
            Spacer(minLength: EditorTheme.smallSpacing)
            trailing
        }
        .font(.theme(.callout))
    }
}

extension WebFieldTitle where Trailing == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.init(title) { EmptyView() }
    }
}
