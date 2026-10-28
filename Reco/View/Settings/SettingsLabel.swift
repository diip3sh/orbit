//
//  SettingsLabel.swift
//  Reco
//

import SwiftUI

/// A row's title with a dim note under it that wraps.
struct SettingsLabel: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    init(_ title: LocalizedStringKey, detail: LocalizedStringKey) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
            Text(detail)
                .font(.theme(.subheadline))
                .foregroundStyle(EditorTheme.dim)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
