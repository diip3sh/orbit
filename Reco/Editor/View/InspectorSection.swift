//
//  InspectorSection.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A group of inspector controls under a title that folds it away, with a note below them and a
/// hairline under it all.
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
                // Animated from here, not on this view: the sections below move with it
                withMotion {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
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
                .transition(.opacity.combined(with: .offset(y: -EditorTheme.smallSpacing)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        // The controls are uncovered as the section grows, and covered as it folds
        .clipped()
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(EditorTheme.softHairline)
                .frame(height: 1)
                .padding(.horizontal)
        }
    }
}

extension InspectorSection where Footer == EmptyView {
    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(title, content: content) { EmptyView() }
    }
}
