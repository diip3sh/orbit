//
//  SettingsStore+HDRScreenshots.swift
//  Reco
//

import Foundation

extension SettingsStore {

    /// Screen and area screenshots keep HDR content's brightness and are written as HEIC (macOS 26 and later)
    var capturesHDRScreenshots: Bool {
        get {
            access(keyPath: \.capturesHDRScreenshots)
            return defaults.bool(forKey: "capturesHDRScreenshots")
        }
        set {
            withMutation(keyPath: \.capturesHDRScreenshots) {
                defaults.set(newValue, forKey: "capturesHDRScreenshots")
            }
        }
    }
}
