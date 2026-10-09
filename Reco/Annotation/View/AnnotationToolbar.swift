//
//  AnnotationToolbar.swift
//  Reco
//

import SwiftUI

/// The strip above the shot: the tools, the colour and line width, Undo, Redo and Delete. The card puts Copy and
/// Save after it.
struct AnnotationToolbar: View {

    let editor: AnnotationEditor

    @State private var showsColors = false

    var body: some View {
        HStack(spacing: EditorTheme.tightSpacing) {
            ForEach(AnnotationTool.allCases, id: \.self) { tool in
                toolButton(tool)
            }
            Divider()
                .frame(height: 16)
                .padding(.horizontal, EditorTheme.tightSpacing)
            colorButton
            widthMenu
            Divider()
                .frame(height: 16)
                .padding(.horizontal, EditorTheme.tightSpacing)
            Button("Undo", systemImage: "arrow.uturn.backward", action: editor.undo)
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!editor.canUndo)
                .help("Undo (⌘Z)")
            Button("Redo", systemImage: "arrow.uturn.forward", action: editor.redo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!editor.canRedo)
                .help("Redo (⇧⌘Z)")
            Button("Delete", systemImage: "trash", action: editor.delete)
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(editor.selection == nil || editor.isEditingText)
                .help("Delete the selected mark (⌫)")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(AnnotationToolButtonStyle(isOn: false))
    }

    private func toolButton(_ tool: AnnotationTool) -> some View {
        Button(tool.title, systemImage: tool.symbol) {
            editor.commitText()
            editor.tool = tool
        }
        .buttonStyle(AnnotationToolButtonStyle(isOn: editor.tool == tool))
        // A letter alone would otherwise pick a tool while text is typed
        .keyboardShortcut(editor.isEditingText ? nil : KeyboardShortcut(KeyEquivalent(tool.shortcut), modifiers: []))
        .help("\(tool.title) (\(tool.shortcut.uppercased()))")
    }

    /// The colour as a disc; a click opens the palette
    private var colorButton: some View {
        Button {
            showsColors.toggle()
        } label: {
            Circle()
                .fill(Color(cgColor: editor.color.cgColor))
                .overlay { Circle().strokeBorder(EditorTheme.hairline, lineWidth: 1) }
                .frame(width: 16, height: 16)
        }
        .help("Color")
        .popover(isPresented: $showsColors, arrowEdge: .bottom) {
            HStack(spacing: EditorTheme.smallSpacing) {
                ForEach(Array(AnnotationStyle.colors.enumerated()), id: \.offset) { _, color in
                    Button {
                        editor.color = color
                        showsColors = false
                    } label: {
                        Circle()
                            .fill(Color(cgColor: color.cgColor))
                            .overlay {
                                Circle().strokeBorder(color == editor.color ? EditorTheme.accent : EditorTheme.hairline, lineWidth: 2)
                            }
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(EditorTheme.smallSpacing)
        }
    }

    /// Thin, Regular or Bold, shown as a line of that width
    private var widthMenu: some View {
        Menu {
            ForEach(AnnotationStyle.lineWidths, id: \.self) { width in
                Button {
                    editor.lineWidth = width
                } label: {
                    Label(Self.widthName(width), systemImage: width == editor.lineWidth ? "checkmark" : "")
                }
            }
        } label: {
            Capsule()
                .fill(EditorTheme.ink)
                .frame(width: 16, height: min(editor.lineWidth, 8) / 2 + 1)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Line width: \(Self.widthName(editor.lineWidth))")
    }

    private static func widthName(_ width: Double) -> String {
        switch width {
        case ..<3: "Thin"
        case ..<6: "Regular"
        default: "Bold"
        }
    }
}

/// A 28 pt square, lit when hovered and filled with the accent when its tool is the one in use.
struct AnnotationToolButtonStyle: ButtonStyle {

    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        AnnotationToolButton(configuration: configuration, isOn: isOn)
    }
}

private struct AnnotationToolButton: View {

    let configuration: ButtonStyleConfiguration
    let isOn: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .font(.theme(weight: .medium))
            .foregroundStyle(isOn ? EditorTheme.onAccent : EditorTheme.ink)
            .frame(width: 28, height: 28)
            .background {
                RoundedRectangle(cornerRadius: EditorTheme.smallRadius, style: .continuous)
                    .fill(isOn ? EditorTheme.accentFill : EditorTheme.ink.opacity(isHovered || configuration.isPressed ? 0.08 : 0))
            }
            .contentShape(.rect)
            .opacity(isEnabled ? 1 : 0.35)
            .onHover { isHovered = $0 }
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: isHovered)
    }
}
