//
//  SettingsStore+ScreenshotHistory.swift
//  Reco
//

import Foundation

extension SettingsStore {

    /// How long unsaved screenshots stay in the history (spec 0012)
    var screenshotHistoryRetention: ScreenshotHistoryRetention {
        get {
            access(keyPath: \.screenshotHistoryRetention)
            return defaults.string(forKey: "screenshotHistoryRetention").flatMap(ScreenshotHistoryRetention.init) ?? .month
        }
        set {
            withMutation(keyPath: \.screenshotHistoryRetention) {
                defaults.set(newValue.rawValue, forKey: "screenshotHistoryRetention")
            }
        }
    }

    /// Whether the notch shelf shows the newest screenshots (spec 0013)
    var showsScreenshotsInNotch: Bool {
        get {
            access(keyPath: \.showsScreenshotsInNotch)
            return defaults.object(forKey: "showsScreenshotsInNotch") as? Bool ?? false
        }
        set {
            withMutation(keyPath: \.showsScreenshotsInNotch) {
                defaults.set(newValue, forKey: "showsScreenshotsInNotch")
            }
        }
    }
}
