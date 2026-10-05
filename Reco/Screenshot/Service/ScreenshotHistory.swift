//
//  ScreenshotHistory.swift
//  Reco
//

import Foundation
import OSLog

/// Every screenshot is kept here until it's saved or older than the retention (spec 0012). Files are
/// deleted, not trashed: the point is to free the space.
nonisolated enum ScreenshotHistory {

    static let directory = URL.recoSupport.appending(path: "Screenshots", directoryHint: .isDirectory)

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "ScreenshotHistory")

    /// The one rule for when a history file goes: older than the retention, or any age when it's off
    static func isExpired(created: Date, now: Date, retention: ScreenshotHistoryRetention) -> Bool {
        guard let days = retention.days else { return true }
        return now.timeIntervalSince(created) > TimeInterval(days) * 86_400
    }

    /// Deletes the screenshots that are expired
    @concurrent
    static func prune(retention: ScreenshotHistoryRetention, now: Date = .now, in directory: URL = directory) async {
        // Made at launch, so the Library has a folder to watch before the first screenshot lands in it
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles
        )) ?? []
        for url in urls where url.pathExtension == "png" && url.lastPathComponent.hasPrefix(LibraryItem.screenshotPrefix) {
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            if isExpired(created: created, now: now, retention: retention) {
                delete(url)
            }
        }
    }

    /// Deletes everything in the history
    @concurrent
    static func clear(in directory: URL = directory) async {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        urls.forEach(delete)
    }

    /// Deletes one screenshot's copy, e.g. once it's saved
    @concurrent
    static func remove(named name: String, in directory: URL = directory) async {
        delete(directory.appending(path: name))
    }

    private static func delete(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch CocoaError.fileNoSuchFile {
            // Already gone
        } catch {
            logger.error("Couldn't delete \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}
