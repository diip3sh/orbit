//
//  SettingsStore+ScreenshotTimer.swift
//  Reco
//

import Foundation

extension SettingsStore {

    /// The self-timer before a screenshot taken from the capture toolbar; shortcuts and links never wait
    var screenshotTimer: CountdownDuration {
        get {
            access(keyPath: \.screenshotTimer)
            let seconds = defaults.object(forKey: "screenshotTimer") as? Int
            return seconds.flatMap(CountdownDuration.init(rawValue:)) ?? .off
        }
        set {
            withMutation(keyPath: \.screenshotTimer) {
                defaults.set(newValue.rawValue, forKey: "screenshotTimer")
            }
        }
    }
}
