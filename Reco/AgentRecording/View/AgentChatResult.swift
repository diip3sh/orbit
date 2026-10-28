//
//  AgentChatResult.swift
//  Reco
//

import SwiftUI

/// The movie a run ended with: its name and where and when it was made, opening it in the editor.
struct AgentChatResult: View {
    let movie: URL
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: EditorTheme.mediumSpacing) {
                Image(systemName: "film")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(EditorTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(EditorTheme.ink.opacity(0.08), in: .rect(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(movie.lastPathComponent)
                        .font(.theme(.body, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(Self.subtitle(for: movie, created: Self.creationDate(of: movie), now: .now))
                        .font(.theme(.subheadline))
                        .foregroundStyle(EditorTheme.dim)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(EditorTheme.dim)
                    .accessibilityHidden(true)
            }
            .padding(EditorTheme.mediumSpacing)
        }
        .buttonStyle(.agentCard)
        .agentSide(.leading)
        .accessibilityHint("Opens it in the editor")
    }

    /// "Movies • Today 8:30 PM": the folder and when it was made.
    static func subtitle(for movie: URL, created: Date, now: Date, calendar: Calendar = .current) -> String {
        let day = calendar.isDate(created, inSameDayAs: now) ? "Today" : created.formatted(.dateTime.month().day())
        return "\(movie.deletingLastPathComponent().lastPathComponent) • \(day) \(created.formatted(.dateTime.hour().minute()))"
    }

    private static func creationDate(of movie: URL) -> Date {
        (try? movie.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .now
    }
}
