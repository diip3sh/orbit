//
//  HeaderMenuLabel.swift
//  Reco
//

import SwiftUI

/// A header menu's symbol, name and chevron, for a `headerCapsule`.
struct HeaderMenuLabel: View {
    let title: LocalizedStringKey
    let symbol: String
    var isProminent = false

    var body: some View {
        HStack(spacing: EditorTheme.smallSpacing) {
            Image(systemName: symbol)
                .font(.theme(.body, weight: isProminent ? .semibold : nil))
            Text(title)
                .font(.theme(.body, weight: isProminent ? .semibold : .medium))
            Image(systemName: "chevron.down")
                .font(.theme(.caption, weight: .semibold))
                .imageScale(.small)
                .accessibilityHidden(true)
        }
    }
}
