//
//  SettingsStore+ScreenshotBackground.swift
//  Reco
//

import Foundation

extension SettingsStore {

    /// The background a screenshot's card puts the shot on with Add Background (spec 0004, N14), as JSON, so a
    /// setting added later decodes with its default like a project's canvas does
    var screenshotBackground: ScreenshotBackground {
        get {
            access(keyPath: \.screenshotBackground)
            guard let data = defaults.data(forKey: "screenshotBackground"),
                  let background = try? JSONDecoder().decode(ScreenshotBackground.self, from: data) else {
                return ScreenshotBackground()
            }
            return background
        }
        set {
            withMutation(keyPath: \.screenshotBackground) {
                defaults.set(try? JSONEncoder().encode(newValue), forKey: "screenshotBackground")
            }
        }
    }

    /// Makes the picture at `url`, chosen by the user, the screenshot background's
    func setScreenshotBackgroundImage(_ url: URL) throws {
        let bookmark = try BackgroundImageLoader.bookmark(for: url)
        screenshotBackground.canvas.setImage(bookmark)
    }
}
