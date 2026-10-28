//
//  SettingsPage.swift
//  Reco
//

import SwiftUI

/// A Settings pane on its panel: the pane's title in the title bar's row, and its sections scrolling under it.
/// Toggles, labelled rows and buttons inside take the Settings styles.
struct SettingsPage<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    private static var shape: RoundedRectangle { .rect(cornerRadius: EditorTheme.largeRadius) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.theme(.title3, weight: .semibold))
                .foregroundStyle(EditorTheme.ink)
                .padding(.leading, 24)
                .frame(maxWidth: .infinity, minHeight: SettingsWindowConfigurator.titlebarHeight, alignment: .leading)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, EditorTheme.largeSpacing)
            }
            .hidingTopScrollEdgeEffect()
        }
        .toggleStyle(.settings)
        .labeledContentStyle(.settings)
        .buttonStyle(.settings)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EditorTheme.panel, in: Self.shape)
        .clipShape(Self.shape)
        .overlay(Self.shape.strokeBorder(EditorTheme.ink.opacity(0.05)))
    }
}

private extension View {

    /// Without the edge macOS 26 draws where the scrolling content meets the title bar: the pane's title is
    /// its own header.
    @ViewBuilder
    func hidingTopScrollEdgeEffect() -> some View {
        if #available(macOS 26, *) {
            scrollEdgeEffectHidden(true, for: .top)
        } else {
            self
        }
    }
}
