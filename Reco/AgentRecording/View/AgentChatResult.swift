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
                    .font(.title3)
                    .foregroundStyle(EditorTheme.accent)
                    .frame(width: 36, height: 36)
                    .background(EditorTheme.control, in: .rect(cornerRadius: EditorTheme.smallRadius, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(movie.lastPathComponent)
                        .font(.theme(.callout, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(Self.subtitle(for: movie, created: Self.creationDate(of: movie), now: .now))
                        .font(.theme(.caption))
                        .foregroundStyle(EditorTheme.dim)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(EditorTheme.smallSpacing + EditorTheme.tightSpacing)
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
