//
//  InspectorSection.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A group of inspector controls under a small title, with a note below them.
struct InspectorSection<Content: View, Footer: View>: View {
    let title: LocalizedStringKey
    let content: Content
    let footer: Footer

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.title = title
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.secondary)
            content
            footer
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EditorTheme.hairline)
                .frame(height: 1)
        }
    }
}

extension InspectorSection where Footer == EmptyView {
    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(title, content: content) { EmptyView() }
    }
}
