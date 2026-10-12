//
//  SettingsStore+CopiedScreenshots.swift
//  Reco
//

import Foundation

extension SettingsStore {

    /// Copying a screenshot also saves it into the screenshot folder, so it stays in the Library rather than
    /// only in the history (off by default)
    var savesCopiedScreenshots: Bool {
        get {
            access(keyPath: \.savesCopiedScreenshots)
            return defaults.bool(forKey: "savesCopiedScreenshots")
        }
        set {
            withMutation(keyPath: \.savesCopiedScreenshots) {
                defaults.set(newValue, forKey: "savesCopiedScreenshots")
            }
        }
    }
}
