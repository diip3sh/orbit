//
//  InspectorCard.swift
//  Reco
//

import SwiftUI

/// An inspector group's title in small caps, with room for an action on the right edge (like the crop's
/// Reset). Unlike `InspectorSection`'s header it doesn't fold: the cards are the tab's whole content.
struct InspectorSectionHeader<Trailing: View>: View {
    let title: LocalizedStringKey
    let trailing: Trailing

    init(_ title: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.theme(.caption, weight: .semibold))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(EditorTheme.dim)
            Spacer()
            trailing
        }
    }
}

extension InspectorSectionHeader where Trailing == EmptyView {
    init(_ title: LocalizedStringKey) {
        self.init(title) { EmptyView() }
    }
}

/// A hairline between a card's rows.
struct InspectorHairline: View {
    var body: some View {
        Rectangle()
            .fill(EditorTheme.hairline)
            .frame(height: 1)
    }
}

/// A note under a group's card, in the dim caption the inspector's footers share.
struct InspectorNote: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.theme(.caption))
            .foregroundStyle(EditorTheme.dim)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    /// A row's place inside a card: the card's width, with room around it.
    func inspectorCardRow() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A group of controls on a fill a step over the inspector's column, ringed by a hairline. Wells and
/// tracks inside it sit a step under it, in `EditorTheme.panel`.
struct InspectorCard<Content: View>: View {
    @ViewBuilder let content: Content

    private static var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 10, style: .continuous) }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EditorTheme.control, in: Self.shape)
            .overlay {
                Self.shape.strokeBorder(EditorTheme.hairline)
            }
            .clipShape(Self.shape)
    }
}
