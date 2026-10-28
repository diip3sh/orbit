//
//  WebToolRail.swift
//  Reco
//

import SwiftUI

/// The stage's tools, down a capsule beside the page: add a hover, click, typing or scroll at the playhead (H, C,
/// T, S), and delete the selected clip. The selected clip's kind is lit. Plain keys are safe here: a focused text
/// field takes them first (checked 2026-10-15 by sending key events through `NSApplication.sendEvent`).
struct WebToolRail: View {
    let viewModel: WebRecordingViewModel

    var body: some View {
        VStack(spacing: 3) {
            tool("Add hover clip", action: .hover) {
                viewModel.addPointerClip(.hover)
            }
            tool("Add click clip", action: .click) {
                viewModel.addPointerClip(.click)
            }
            tool("Add typing clip", action: .type) {
                viewModel.addPointerClip(.type)
            }

            tool("Add scroll clip", symbol: ScrollClip.symbol, key: KeyEquivalent(ScrollClip.key), isSelected: viewModel.selectedScrollClip != nil) {
                Task {
                    await viewModel.addScrollClip()
                }
            }
            .disabled(!viewModel.canAddScrollClip)

            Rectangle()
                .fill(EditorTheme.hairline)
                .frame(width: 20, height: 1)
                .padding(.vertical, 4)

            tool("Delete clip", symbol: "trash", key: .delete, isSelected: false) {
                viewModel.deleteSelection()
            }
            .disabled(viewModel.selection == nil || !viewModel.isEditable)
        }
        .padding(5)
        .background(EditorTheme.panel, in: .capsule)
        .webField()
        .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
    }

    /// The selected cursor clip's action, which lights its tool.
    private var selected: PointerClip.Action? {
        viewModel.selectedPointerClip?.action
    }

    /// The tool that adds a cursor clip of `action`, lit while one is selected.
    private func tool(_ title: LocalizedStringKey, action: PointerClip.Action, add: @escaping () -> Void) -> some View {
        tool(title, symbol: action.symbol, key: KeyEquivalent(action.key), isSelected: selected == action, action: add)
            .disabled(!viewModel.canAddPointerClip)
    }

    /// A tool named `title`, which its tip shows with its key.
    private func tool(
        _ title: LocalizedStringKey, symbol: String, key: KeyEquivalent, isSelected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(title, systemImage: symbol, action: action)
            .font(.system(size: 14, weight: .medium))
            .buttonStyle(EditorIconButtonStyle(diameter: 36, isSelected: isSelected))
            // ⌫ is the timeline's own delete command; only the tip shows it
            .keyboardShortcut(key == .delete ? nil : KeyboardShortcut(key, modifiers: []))
            .modifier(WebToolTip(text: title, key: key == .delete ? "⌫" : String(key.character).uppercased()))
    }
}

/// A tip beside a rail button after the pointer rests on it: what it does and its key.
private struct WebToolTip: ViewModifier {
    let text: LocalizedStringKey
    let key: String

    @State private var isHovered = false
    @State private var isShown = false

    func body(content: Content) -> some View {
        content
            .onHover { isHovered = $0 }
            .task(id: isHovered) {
                guard isHovered else {
                    isShown = false
                    return
                }
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { return }
                isShown = true
            }
            .overlay(alignment: .leading) {
                if isShown {
                    HStack(spacing: EditorTheme.smallSpacing) {
                        Text(text)
                            .font(.theme(.callout, weight: .medium))
                        Text(key)
                            .font(.theme(.caption, weight: .medium, .mono))
                            .foregroundStyle(EditorTheme.dim)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(EditorTheme.ink.opacity(0.08), in: .rect(cornerRadius: 4))
                    }
                    .foregroundStyle(EditorTheme.ink)
                    .padding(.leading, 10)
                    .padding(.trailing, 4)
                    .frame(height: 24)
                    .editorSurface(in: .rect(cornerRadius: 6), fill: EditorTheme.raised)
                    .fixedSize()
                    .offset(x: 44)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .editorMotion(EditorTheme.quickMotion, value: isShown)
    }
}
