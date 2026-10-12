//
//  AgentChatFailure.swift
//  Reco
//

import SwiftUI

/// Why the chat's last run failed, with Retry, on a quiet surface.
struct AgentChatFailure: View {
    let reason: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.mediumSpacing) {
            AgentChatMessageRow(role: .failure, text: reason)
            Button("Retry", systemImage: "arrow.clockwise", action: retry)
                .buttonStyle(.editorSecondary)
        }
        .padding(EditorTheme.mediumSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EditorTheme.control, in: .rect(cornerRadius: 10))
    }
}
