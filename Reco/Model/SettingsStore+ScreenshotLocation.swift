//
//  SettingsStore+ScreenshotLocation.swift
//  Reco
//

import Foundation

extension SettingsStore {

    /// Where screenshots go unless the user picks another folder: the Desktop, as macOS does
    nonisolated static let defaultScreenshotDirectory = URL.userHome.appending(path: "Desktop", directoryHint: .isDirectory)

    /// The folder saved screenshots go to. Kept as a plain path (unsandboxed, no bookmark is needed) and read
    /// back as a directory URL, so a folder compares equal however it was picked, with or without a trailing slash.
    var screenshotDirectory: URL {
        get {
            access(keyPath: \.screenshotDirectory)
            guard let path = defaults.string(forKey: "screenshotDirectory") else { return Self.defaultScreenshotDirectory }
            return URL(filePath: path, directoryHint: .isDirectory)
        }
        set {
            withMutation(keyPath: \.screenshotDirectory) {
                defaults.set(newValue.path(percentEncoded: false), forKey: "screenshotDirectory")
            }
        }
    }

    var hasCustomScreenshotDirectory: Bool {
        screenshotDirectory != Self.defaultScreenshotDirectory
    }

    func resetScreenshotDirectory() {
        withMutation(keyPath: \.screenshotDirectory) {
            defaults.removeObject(forKey: "screenshotDirectory")
        }
    }
}
