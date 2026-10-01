//
//  InspectorSection.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A group of inspector controls under a quiet title that folds it away, with a note below them.
struct InspectorSection<Content: View, Footer: View>: View {
    let title: LocalizedStringKey
    let content: Content
    let footer: Footer

    @State private var isExpanded = true
    @Environment(\.isEnabled) private var isEnabled

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.title = title
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.mediumSpacing) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    Text(title)
                        .foregroundStyle(EditorTheme.dim)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .imageScale(.small)
                        .foregroundStyle(EditorTheme.faint)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? Text("Expanded") : Text("Collapsed"))

            if isExpanded {
                VStack(alignment: .leading, spacing: EditorTheme.mediumSpacing) {
                    // Text in ink doesn't dim by itself when disabled
                    content
                        .opacity(isEnabled ? 1 : 0.4)
                    footer
                        .font(.caption)
                        .foregroundStyle(EditorTheme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .editorMotion(value: isExpanded)
    }
}

extension InspectorSection where Footer == EmptyView {
    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(title, content: content) { EmptyView() }
    }
}
