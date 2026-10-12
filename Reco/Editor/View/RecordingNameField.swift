//
//  RecordingNameField.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import SwiftUI

/// The recording's name in the title bar. A click turns it into a field: Return or leaving it renames, Esc
/// keeps the name.
struct RecordingNameField: View {
    let name: String
    @Binding var isRenaming: Bool

    /// Called with what was typed when it differs from `name` and isn't blank.
    let rename: (String) -> Void

    @State private var draft = ""

    var body: some View {
        if isRenaming {
            // Sized by the text, between the limits, with the field laid over it
            Text(draft.isEmpty ? " " : draft)
                .font(.theme(.headline))
                .lineLimit(1)
                .padding(.trailing, Self.padding)
                .hidden()
                .frame(minWidth: Self.minimumWidth, maxWidth: Self.maximumWidth, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
                .overlay {
                    NameEditor(text: $draft, onEnd: finish) { isRenaming = false }
                }
                .padding(.horizontal, Self.padding)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Recording name")
        } else {
            Button {
                draft = name
                isRenaming = true
            } label: {
                Text(name)
                    .font(.theme(.headline))
                    .foregroundStyle(EditorTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: Self.maximumWidth)
                    .padding(.horizontal, Self.padding)
            }
            .buttonStyle(NameButtonStyle())
            .help("Rename")
            .accessibilityLabel("Recording name")
            .accessibilityValue(name)
            .accessibilityHint("Renames the recording")
        }
    }

    private static let minimumWidth: CGFloat = 120
    private static let maximumWidth: CGFloat = 360
    private static let padding: CGFloat = 8

    /// Ends editing, renaming unless the name is blank or unchanged.
    private func finish() {
        guard isRenaming else { return }
        isRenaming = false
        let draft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !draft.isEmpty, draft != name {
            rename(draft)
        }
    }
}

/// The field itself, in AppKit: `@FocusState` didn't reach a text field in the window's toolbar (focus set as
/// it appeared was lost, and typing went nowhere), and its field editor took Esc before `onExitCommand` saw it.
private struct NameEditor: NSViewRepresentable {
    @Binding var text: String

    /// Return, or focus leaving the field
    let onEnd: () -> Void

    /// Esc
    let onCancel: () -> Void

    func makeNSView(context: Context) -> FocusedTextField {
        let field = FocusedTextField(string: text)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .theme(.headline)
        field.textColor = NSColor(resource: .ink)
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: FocusedTextField, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NameEditor

        init(parent: NameEditor) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            parent.text = (notification.object as? NSTextField)?.stringValue ?? parent.text
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            parent.onEnd()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
            parent.onCancel()
            return true
        }
    }
}

/// Takes focus, its text selected, as soon as it is in the window.
private final class FocusedTextField: NSTextField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}

/// The name at rest: plain text that lights up under the pointer, a step more as it's pressed.
private struct NameButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        NameButton(configuration: configuration)
    }
}

private struct NameButton: View {
    let configuration: ButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .padding(.vertical, 4)
            .background(EditorTheme.ink.opacity(fill), in: .rect(cornerRadius: 6, style: .continuous))
            .contentShape(.rect(cornerRadius: 6, style: .continuous))
            .opacity(isEnabled ? 1 : 0.5)
            // The press shows on the frame it lands; only hover and release ease
            .editorMotion(configuration.isPressed ? nil : EditorTheme.quickMotion, value: fill)
            .onHover { isHovered = $0 }
    }

    private var fill: Double {
        guard isEnabled else { return 0 }
        return configuration.isPressed ? 0.14 : isHovered ? 0.08 : 0
    }
}
