//
//  WebTake.swift
//  Reco
//

import Foundation

/// What a web take was made from, saved as `<name>.web.json` next to its movie: the script, and the
/// conversation with the agent that wrote it, if one did. The editor's agent chat reads it to record
/// the take again with changes (spec 0008).
nonisolated struct WebTake: Codable, Equatable, Sendable {

    /// Bumped whenever the file layout changes incompatibly.
    static let currentVersion = 1

    var version = currentVersion
    var script: WebScript
    var conversation: [AgentChatMessage] = []

    /// The file for a take's movie: same folder and base name, `.web.json` extension.
    static func fileURL(for movie: URL) -> URL {
        movie.deletingPathExtension().appendingPathExtension("web").appendingPathExtension("json")
    }

    /// The take's file, or `nil` when it has none, e.g. a screen recording.
    @concurrent
    static func read(for movie: URL) async throws -> WebTake? {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL(for: movie))
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        }
        let take = try JSONDecoder().decode(WebTake.self, from: data)
        guard take.version == currentVersion else { throw UnsupportedVersionError(version: take.version) }
        return take
    }

    /// Writes atomically, so a crash mid-save never leaves a truncated file.
    @concurrent
    func write(for movie: URL) async throws {
        try JSONEncoder().encode(self).write(to: Self.fileURL(for: movie), options: .atomic)
    }
}
