//
//  SettingsSidebar.swift
//  Reco
//

import SwiftUI

/// The Settings window's list of panes, on a translucent column with the traffic lights at its top.
struct SettingsSidebar: View {
    @Binding var selection: SettingsTab

    private static var shape: RoundedRectangle { .rect(cornerRadius: EditorTheme.largeRadius) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // The traffic lights' row: `SettingsWindowConfigurator` moves them here
            Color.clear
                .frame(height: SettingsWindowConfigurator.titlebarHeight)

            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .buttonStyle(SettingsSidebarRowStyle(isSelected: selection == tab))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, EditorTheme.spacing)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(EditorTheme.panel.opacity(0.3), in: Self.shape)
        .overlay(Self.shape.strokeBorder(EditorTheme.ink.opacity(0.1)))
    }
}

/// A pane's row: its symbol and name, lifted onto a raised pill while it's showing. The Library's sections too.
struct SettingsSidebarRowStyle: ButtonStyle {
    let isSelected: Bool

    private static var shape: RoundedRectangle { .rect(cornerRadius: 10) }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(SettingsSidebarLabelStyle(isSelected: isSelected))
            .font(.theme(.body, weight: isSelected ? .semibold : .medium))
            .foregroundStyle(EditorTheme.ink)
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .background {
                if isSelected {
                    Self.shape
                        .fill(EditorTheme.ink.opacity(0.11))
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                    Self.shape.strokeBorder(EditorTheme.ink.opacity(0.08))
                } else if configuration.isPressed {
                    Self.shape.fill(EditorTheme.ink.opacity(0.06))
                }
            }
            .contentShape(Self.shape)
    }
}

/// The symbol in an 18 pt square before the name, dim until the pane is chosen.
private struct SettingsSidebarLabelStyle: LabelStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon
                .font(.theme(.title3))
                .foregroundStyle(isSelected ? EditorTheme.ink : EditorTheme.dim)
                .frame(width: 18, height: 18)
            configuration.title
                .lineLimit(1)
        }
    }
}
