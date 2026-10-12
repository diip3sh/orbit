//
//  SettingsStore+DesktopIcons.swift
//  Reco
//

import Foundation

extension SettingsStore {

    /// Whether display recordings keep Finder's desktop icons. The desktop itself is untouched either way.
    var showDesktopIcons: Bool {
        get {
            access(keyPath: \.showDesktopIcons)
            return defaults.object(forKey: "showDesktopIcons") as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.showDesktopIcons) {
                defaults.set(newValue, forKey: "showDesktopIcons")
            }
        }
    }
}
