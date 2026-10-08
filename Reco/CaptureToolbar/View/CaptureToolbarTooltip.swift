//
//  CaptureToolbarTooltip.swift
//  Reco
//

import SwiftUI

extension View {

    /// The tooltip above the bar: what this control does now, in a word or two, and the key that does
    /// it. Ours, not the system's, so it appears sooner, follows what the control does, and moves
    /// straight to the next control the pointer rests on.
    func captureToolbarTooltip(_ text: @autoclosure @escaping () -> String, shortcut: String? = nil) -> some View {
        modifier(CaptureToolbarTooltipModifier(text: text, shortcut: shortcut))
    }

    /// Answers `shortcut` while the bar has key, and names its key in the tooltip
    func captureToolbarTooltip(_ text: @autoclosure @escaping () -> String, shortcut: CaptureToolbarShortcut) -> some View {
        keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
            .modifier(CaptureToolbarTooltipModifier(text: text, shortcut: shortcut.symbol))
    }
}

/// Reports the hover into the toolbar's shared tooltips, with the control's mid-x in the bar's
/// coordinate space so its tooltip centres on it. The text is re-read when it changes while hovered,
/// so the tooltip follows what the control does (Pause becomes Resume, On becomes Off).
private struct CaptureToolbarTooltipModifier: ViewModifier {
    let text: () -> String
    let shortcut: String?

    @Environment(CaptureToolbarTooltips.self) private var tooltips
    @State private var midX: CGFloat = .zero
    @State private var isHovered = false
    @State private var appearTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self, of: { $0.frame(in: .named(CaptureToolbarView.barSpaceName)).midX }, action: { midX = $0 })
            .onHover { hovering in
                isHovered = hovering
                appearTask?.cancel()
                appearTask = nil
                if hovering {
                    let delay = tooltips.appearDelay()
                    guard delay > .zero else {
                        tooltips.hover(text(), shortcut: shortcut, at: midX)
                        return
                    }
                    appearTask = Task {
                        try? await Task.sleep(for: delay)
                        guard !Task.isCancelled else { return }
                        tooltips.hover(text(), shortcut: shortcut, at: midX)
                    }
                } else {
                    tooltips.unhover()
                }
            }
            .onChange(of: text()) { _, newText in
                guard isHovered else { return }
                tooltips.retext(newText)
            }
    }
}

/// The tooltip's content, in its own window above the bar: a raised bubble with a tail pointing at the
/// control, as the Dock's are. It only fades: in quickly so it answers the rest, out quicker still so it
/// never trails the pointer. Moving to another control swaps its text and place at once, without a fade,
/// and a change of what the control does swaps the text in place; nothing slides or scales.
struct CaptureToolbarTooltipView: View {
    let tooltips: CaptureToolbarTooltips

    /// Room for the bubble's shadow, inside the window
    static let margin: CGFloat = 6

    /// The window's size for `target`, measured from the bubble itself: the view's own fitting size still
    /// holds the previous text when a hover lands, so a window sized from it let the bubble spill over the bar.
    static func size(for target: CaptureToolbarTooltips.Target) -> CGSize {
        let bubble = CaptureToolbarTooltipBubble(text: target.text, shortcut: target.shortcut, pointsUp: false)
        let fitted = NSHostingView(rootView: bubble.themed()).fittingSize
        return CGSize(width: fitted.width.rounded(.up) + margin * 2, height: fitted.height.rounded(.up) + margin * 2)
    }

    var body: some View {
        ZStack {
            if let target = tooltips.target, tooltips.isShown {
                CaptureToolbarTooltipBubble(text: target.text, shortcut: target.shortcut, pointsUp: tooltips.pointsUp)
                    .transition(.opacity)
            }
        }
        // A fade is kept with Reduce Motion: nothing moves
        .animation(tooltips.isShown ? .easeOut(duration: 0.12) : .easeIn(duration: 0.08), value: tooltips.isShown)
        .padding(Self.margin)
        .fixedSize()
    }
}

/// The Dock's tooltip: medium text on a raised surface, a hairline edge, and a tail; the key that does the
/// same, dimmed after it, as a menu shows it
private struct CaptureToolbarTooltipBubble: View {
    let text: String
    let shortcut: String?
    let pointsUp: Bool

    var body: some View {
        let shape = TooltipBubbleShape(pointsUp: pointsUp)
        HStack(spacing: 6) {
            Text(text)
                .foregroundStyle(EditorTheme.ink)
            if let shortcut {
                Text(shortcut)
                    .font(.theme(.body, weight: .medium, .mono))
                    .foregroundStyle(EditorTheme.dim)
            }
        }
        .font(.theme(.body, weight: .medium))
        .lineLimit(1)
        .padding(.horizontal, EditorTheme.mediumSpacing)
        .padding(.vertical, 6)
        .padding(pointsUp ? .top : .bottom, TooltipBubbleShape.tailHeight)
        .background(EditorTheme.raised, in: shape)
        .overlay(shape.stroke(EditorTheme.hairline))
        .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
    }
}

/// A rounded bubble with a tail centred on its bottom edge, or its top when the tooltip sits under the bar
nonisolated private struct TooltipBubbleShape: Shape {
    let pointsUp: Bool

    static let tailHeight: CGFloat = 6
    static let tailWidth: CGFloat = 14
    static let cornerRadius: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        let tail = Self.tailHeight
        let body = pointsUp
            ? CGRect(x: rect.minX, y: rect.minY + tail, width: rect.width, height: rect.height - tail)
            : CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tail)
        var path = Path(roundedRect: body, cornerRadius: Self.cornerRadius, style: .continuous)

        let edge = pointsUp ? body.minY : body.maxY
        let tip = pointsUp ? rect.minY : rect.maxY
        var tailPath = Path()
        tailPath.move(to: CGPoint(x: rect.midX - Self.tailWidth / 2, y: edge))
        // Rounded tip, so it reads as part of the bubble rather than a sharp arrow
        tailPath.addQuadCurve(to: CGPoint(x: rect.midX, y: tip), control: CGPoint(x: rect.midX - 2, y: tip))
        tailPath.addQuadCurve(to: CGPoint(x: rect.midX + Self.tailWidth / 2, y: edge), control: CGPoint(x: rect.midX + 2, y: tip))
        tailPath.closeSubpath()
        path.addPath(tailPath)
        return path.normalized()
    }
}
