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
    @FocusState private var isFocused: Bool

    var body: some View {
        if isRenaming {
            TextField("Name", text: $draft)
                .textFieldStyle(.plain)
                .font(.headline)
                .frame(minWidth: Self.minimumWidth, maxWidth: Self.maximumWidth)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, Self.padding)
                .focused($isFocused)
                .onSubmit(finish)
                .onExitCommand { isRenaming = false }
                .onChange(of: isFocused) { _, isFocused in
                    if !isFocused {
                        finish()
                    }
                }
                .task {
                    isFocused = true
                    // Once the field has taken focus and has its text editor
                    await Task.yield()
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
                .accessibilityLabel("Recording name")
        } else {
            Button {
                draft = name
                isRenaming = true
            } label: {
                Text(name)
                    .font(.headline)
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
            .background(.primary.opacity(fill), in: .rect(cornerRadius: 6, style: .continuous))
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
