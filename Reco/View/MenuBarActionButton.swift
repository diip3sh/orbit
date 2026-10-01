//
//  MenuBarActionButton.swift
//  Reco
//
//  Created by Joshua Sattler on 29.01.26.
//

import SwiftUI

/// An action row of the menu bar window: its symbol in a fixed column, then its title
struct MenuBarActionButton: View {
    let title: String
    var systemImage: String?
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                Text(title)
                    .font(.body.weight(.medium))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .buttonStyle(.menuRow)
        .disabled(isDisabled)
    }
}
