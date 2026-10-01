//
//  TemporaryDefaults.swift
//  RecoTests
//

import Foundation

/// Fresh, empty `UserDefaults` suites that are removed when this goes away.
///
/// A suite named by a plain string is stored in `~/Library/Preferences`, and its file comes back
/// after the test: the preferences daemon writes an empty one later, whatever is deleted before.
/// Hundreds of `com.diip3sh.RecoTests.<UUID>.plist` piled up that way. A suite named by a path is
/// stored at that path instead, in the temporary folder.
nonisolated final class TemporaryDefaults {

    /// The suites made so far, by the path that names them.
    private(set) var domains: [String] = []

    func make() -> UserDefaults {
        let domain = FileManager.default.temporaryDirectory.appending(path: "com.diip3sh.RecoTests.\(UUID().uuidString)").path(percentEncoded: false)
        domains.append(domain)
        return UserDefaults(suiteName: domain) ?? .standard
    }

    deinit {
        for domain in domains {
            UserDefaults.standard.removePersistentDomain(forName: domain)
            try? FileManager.default.removeItem(atPath: domain + ".plist")
        }
    }
}
