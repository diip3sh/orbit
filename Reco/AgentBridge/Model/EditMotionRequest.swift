//
//  EditMotionRequest.swift
//  Reco
//

import Foundation

/// The arguments of the `edit_motion` tool: a motion video, new or existing, and the operations to
/// apply to it (spec 0011, *Agent*).
nonisolated struct EditMotionRequest: Codable, Equatable, Sendable {

    /// A `.motion` bundle's path, as an earlier `edit_motion` returned it; `nil` for a new video.
    var bundle: String?

    /// A new video's name.
    var name: String?
    var operations: [MotionEdit]

    /// The bundle named, once it's known to be one; `nil` for a new video.
    func existingBundle() throws(AgentToolError) -> URL? {
        guard let bundle else { return nil }
        let url = URL(filePath: bundle)
        guard bundle.hasPrefix("/"), url.pathExtension == MotionStore.bundleExtension,
              FileManager.default.fileExists(atPath: MotionStore.documentURL(in: url).path(percentEncoded: false)) else {
            throw .invalidArgument("bundle must be the path of a .motion video, as edit_motion returns it; leave it out to start one.")
        }
        return url
    }

    /// `document` with every operation applied in turn, then checked whole: all or nothing.
    func edited(_ document: MotionDocument) throws(AgentToolError) -> MotionDocument {
        var edited = document
        for (index, operation) in operations.enumerated() {
            do {
                try operation.apply(to: &edited)
            } catch {
                throw .invalidArgument("Operation \(index) (\(operation.operation.rawValue)): \(error.reason) Nothing was changed.")
            }
        }
        do {
            try edited.validate()
        } catch {
            throw .invalidArgument("The edit would leave the video invalid: \(error.localizedDescription) Nothing was changed.")
        }
        return edited
    }

    /// Where a new video named `name` goes in `folder`: a name a file can have, made unique.
    static func newBundle(named name: String?, in folder: URL, date: Date = .now) -> URL {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleaned = String((name ?? "").unicodeScalars.filter(allowed.contains).map(Character.init)).trimmingCharacters(in: .whitespaces)
        let base = cleaned.isEmpty ? "Reco_Motion_\(date.formatted(.iso8601.year().month().day().dateSeparator(.dash)))" : String(cleaned.prefix(80))
        var url = folder.appending(path: "\(base).\(MotionStore.bundleExtension)")
        var number = 2
        while FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            url = folder.appending(path: "\(base) \(number).\(MotionStore.bundleExtension)")
            number += 1
        }
        return url
    }
}
