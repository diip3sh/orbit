//
//  AgentSkill.swift
//  Reco
//

import Foundation

/// Reco's methods for motion films, shipped in the app as skills: the launch film (spec 0012, Q4) and motion design
/// (spec 0014). Claude Code finds them in its run's folder and loads the one a film needs; motion design's references
/// are files beside its `SKILL.md`, read one at a time when its method says so. Agents without skills get the launch
/// film's method in their prompt.
nonisolated enum AgentSkill {

    static let launchFilmName = "reco-launch-film"

    /// Where Claude Code finds it, relative to the run's folder.
    static let launchFilmPath = ".claude/skills/\(launchFilmName)/SKILL.md"

    /// The skill's file: its front matter (name, description) and the method.
    static let launchFilm = resource(launchFilmName)

    /// The method without its front matter, for a prompt.
    static var launchFilmMethod: String {
        method(of: launchFilm)
    }

    static let motionDesignName = "reco-motion-design"

    /// Its references, bundled as `reco-motion-design-<name>.md`: the reference film, the moves, recipes, longer
    /// films and a whole example.
    static let motionDesignReferences = ["film", "moves", "recipes", "longer", "example"]

    static let motionDesign = resource(motionDesignName)

    /// Every skill file a motion run gets, by its path relative to the run's folder.
    static let files: [String: String] = {
        var files = [launchFilmPath: launchFilm, ".claude/skills/\(motionDesignName)/SKILL.md": motionDesign]
        for name in motionDesignReferences {
            files[".claude/skills/\(motionDesignName)/reference/\(name).md"] = resource("\(motionDesignName)-\(name)")
        }
        return files
    }()

    /// The folder the skills are in, which Claude Code may read and nothing else on the disk.
    static let folder = ".claude/skills"

    private static func resource(_ name: String) -> String {
        Bundle.main.url(forResource: name, withExtension: "md").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }

    private static func method(of skill: String) -> String {
        let parts = skill.split(separator: "---\n", maxSplits: 2, omittingEmptySubsequences: false)
        return String(parts.count == 3 ? parts[2] : Substring(skill)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
