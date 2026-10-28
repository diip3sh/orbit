//
//  SettingsPicker.swift
//  Reco
//

import SwiftUI

/// A Settings row choosing one of `content`'s tagged options from a menu, opened from a pill showing `value`.
/// A `Menu` rather than a `Picker`, whose pop-up button can't be restyled.
struct SettingsPicker<Selection: Hashable, Content: View>: View {
    let title: LocalizedStringKey
    @Binding var selection: Selection
    let value: String
    @ViewBuilder let content: Content

    init(
        _ title: LocalizedStringKey,
        selection: Binding<Selection>,
        value: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        _selection = selection
        self.value = value
        self.content = content()
    }

    var body: some View {
        LabeledContent(title) {
            Menu {
                Picker(title, selection: $selection) {
                    content
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                Text(value)
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(SettingsPopUpStyle())
            .fixedSize()
        }
    }
}

/// The menu's pill: its value and the up-and-down chevron on a faint capsule.
private struct SettingsPopUpStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.label
                .font(.theme(.callout, weight: .medium))
                .foregroundStyle(EditorTheme.ink)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.theme(.caption, weight: .semibold))
                .foregroundStyle(EditorTheme.dim)
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .frame(height: 26)
        .background(EditorTheme.ink.opacity(configuration.isPressed ? 0.12 : 0.08), in: .capsule)
        .contentShape(.capsule)
    }
}
