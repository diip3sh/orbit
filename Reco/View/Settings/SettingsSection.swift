//
//  SettingsSection.swift
//  Reco
//

import SwiftUI

/// A group of a Settings pane: its title, its rows on a card with hairlines between them, and an optional note
/// under the card.
struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey?
    let footer: LocalizedStringKey?
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey? = nil, footer: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    private static var shape: RoundedRectangle { .rect(cornerRadius: EditorTheme.largeRadius) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.theme(.callout, weight: .medium))
                    .foregroundStyle(EditorTheme.dim)
                    .padding(.leading, 4)
            }

            Group(subviews: content) { rows in
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        if row.id != rows.first?.id {
                            Rectangle()
                                .fill(EditorTheme.hairline)
                                .frame(height: 1)
                                .padding(.horizontal, 14)
                        }
                        row
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                }
            }
            .background(EditorTheme.ink.opacity(0.07), in: Self.shape)
            .overlay(Self.shape.strokeBorder(EditorTheme.ink.opacity(0.12)))

            if let footer {
                Text(footer)
                    .font(.theme(.subheadline))
                    .foregroundStyle(EditorTheme.dim)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }
}
