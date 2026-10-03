//
//  StatusBanner.swift
//  Reco
//

import SwiftUI

/// Something that went wrong, on glass over a window's content, with a button to put it away: the
/// studio windows' one way of reporting a problem (Web Recording, Library, Editor).
struct StatusBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: EditorTheme.smallSpacing) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
                .lineLimit(2)
            Button("Dismiss", systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(EditorTheme.dim)
        }
        .padding(.horizontal, EditorTheme.mediumSpacing)
        .padding(.vertical, EditorTheme.smallSpacing)
        .editorGlass(in: .capsule)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
