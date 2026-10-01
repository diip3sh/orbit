//
//  ContainerMigration.swift
//  Reco
//

import Foundation
import OSLog

/// Brings settings and saved files over from the App Sandbox container the app used until
/// 2026-10-01 (spec 0007), once: on the first launch with nothing of its own yet. The container
/// stays untouched.
///
/// Carries the agent bridge's token too, so agents that are connected stay connected.
nonisolated enum ContainerMigration {

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "ContainerMigration")

    /// The container's settings when there are some and the app has none of its own yet.
    static func preferencesToCopy(container: [String: Any]?, current: [String: Any]?) -> [String: Any]? {
        guard let container, !container.isEmpty, current?.isEmpty ?? true else { return nil }
        return container
    }

    /// The `names` that aren't at the destination yet. Symbolic links are left out by the caller.
    static func filesToCopy(names: [String], exists: (String) -> Bool) -> [String] {
        names.filter { !exists($0) }
    }

    /// Copies the container's settings into `defaults` and its Application Support files into
    /// `destination`, if the settings have something to copy. `domain` is the name of `defaults`'
    /// own settings when it isn't `bundleID`, as in a test. Failures are skipped: the user sets
    /// things again. Only reasons are logged, never values.
    static func run(
        home: URL = .userHome,
        defaults: UserDefaults = .standard,
        bundleID: String = Bundle.main.bundleIdentifier ?? "com.diip3sh.Reco",
        domain: String? = nil,
        destination: URL = .recoSupport
    ) {
        let data = home.appending(path: "Library/Containers/\(bundleID)/Data/Library")
        let container = readPreferences(at: data.appending(path: "Preferences/\(bundleID).plist"))
        guard let preferences = preferencesToCopy(container: container, current: defaults.persistentDomain(forName: domain ?? bundleID)) else {
            return
        }
        for (key, value) in preferences {
            defaults.set(value, forKey: key)
        }
        copyFiles(from: data.appending(path: "Application Support"), to: destination)
        logger.info("Moved \(preferences.count) settings over from the sandbox container")
    }

    private static func readPreferences(at url: URL) -> [String: Any]? {
        do {
            let data = try Data(contentsOf: url)
            return try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        } catch {
            // No container, or macOS didn't let this app read it
            logger.info("No settings to move over: \(error.localizedDescription)")
            return nil
        }
    }

    private static func copyFiles(from source: URL, to destination: URL) {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: source.path(percentEncoded: false)) else { return }
        let regular = names.filter { name in
            (try? source.appending(path: name).resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink != true
        }
        let missing = filesToCopy(names: regular) { manager.fileExists(atPath: destination.appending(path: $0).path(percentEncoded: false)) }
        for name in missing {
            do {
                try manager.createDirectory(at: destination, withIntermediateDirectories: true)
                try manager.copyItem(at: source.appending(path: name), to: destination.appending(path: name))
            } catch {
                logger.info("Couldn't move a file over: \(error.localizedDescription)")
            }
        }
    }
}
