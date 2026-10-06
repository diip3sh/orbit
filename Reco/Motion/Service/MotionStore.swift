//
//  MotionStore.swift
//  Reco
//

import Foundation

/// Reads and writes a motion bundle's document, off the main actor.
nonisolated enum MotionStore {

    static let bundleExtension = "motion"

    static func documentURL(in bundle: URL) -> URL {
        bundle.appending(path: "document.json")
    }

    /// Throws ``UnsupportedVersionError`` for another version and ``MotionDocumentError`` for a
    /// document that can't be drawn.
    @concurrent
    static func read(_ bundle: URL) async throws -> MotionDocument {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(contentsOf: documentURL(in: bundle)))
        try document.validate()
        return document
    }

    /// Creates the bundle if needed and writes atomically, so a crash mid-save never leaves a
    /// truncated file.
    @concurrent
    static func write(_ document: MotionDocument, to bundle: URL) async throws {
        try FileManager.default.createDirectory(at: bundle.appending(path: "assets"), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document).write(to: documentURL(in: bundle), options: .atomic)
    }
}
