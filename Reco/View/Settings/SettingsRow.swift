//
//  SettingsRow.swift
//  Reco
//

import SwiftUI

/// A Settings card's row: the label on the left in medium ink, its control or value on the right edge. Disabled,
/// the whole row fades, since ink text doesn't dim by itself.
struct SettingsRow<Label: View, Trailing: View>: View {
    @ViewBuilder let label: Label
    @ViewBuilder let trailing: Trailing

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: EditorTheme.spacing) {
            label
                .font(.theme(.body, weight: .medium))
                .foregroundStyle(EditorTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
                .font(.theme(.body))
                .foregroundStyle(EditorTheme.dim)
        }
        .opacity(isEnabled ? 1 : 0.45)
    }
}
