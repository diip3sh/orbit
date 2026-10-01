//
//  AgentRecordingFailure.swift
//  Reco
//

import SwiftUI

/// Why the last run failed, with Retry, between the fields and the footer.
struct AgentRecordingFailure: View {
    let reason: String
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: EditorTheme.smallSpacing) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(EditorTheme.dim)
                .accessibilityHidden(true)
            Text(reason)
                .font(.callout)
                .lineLimit(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Retry", systemImage: "arrow.clockwise", action: retry)
                .buttonStyle(.editorPrimary)
        }
        .padding(EditorTheme.spacing)
        .accessibilityElement(children: .contain)
    }
}
