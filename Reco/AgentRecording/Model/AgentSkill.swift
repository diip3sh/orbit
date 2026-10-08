//
//  AgentSkill.swift
//  Reco
//

import Foundation

/// Reco's method for launch films, shipped in the app as a skill (spec 0012, Q4): Claude Code finds it in
/// its run's folder and loads it when it needs it; agents without skills get its text in their prompt.
nonisolated enum AgentSkill {

    static let launchFilmName = "reco-launch-film"

    /// Where Claude Code finds it, relative to the run's folder.
    static let launchFilmPath = ".claude/skills/\(launchFilmName)/SKILL.md"

    /// The skill's file: its front matter (name, description) and the method.
    static let launchFilm: String = Bundle.main.url(forResource: launchFilmName, withExtension: "md")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""

    /// The method without its front matter, for a prompt.
    static var launchFilmMethod: String {
        let parts = launchFilm.split(separator: "---\n", maxSplits: 2, omittingEmptySubsequences: false)
        return String(parts.count == 3 ? parts[2] : Substring(launchFilm)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
