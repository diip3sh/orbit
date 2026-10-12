//
//  EditorViewModel+Background.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import Foundation

extension EditorViewModel {

    /// Reads the picture `bookmark` opens into ``resources`` unless it's the one there already. Returns `false`
    /// when there should be a picture and it couldn't be read.
    func updateBackgroundImage(for bookmark: Data?) async -> Bool {
        guard bookmark != backgroundBookmark else { return true }
        resources.background = nil
        backgroundImageURL = nil
        if let bookmark, let loaded = await BackgroundImageLoader.image(from: bookmark) {
            resources.background = loaded.image
            backgroundImageURL = loaded.url
        }
        backgroundBookmark = bookmark
        return bookmark == nil || resources.background != nil
    }

    /// Reads the system's wallpapers, once.
    func loadWallpapers() async {
        guard wallpapers.isEmpty else { return }
        wallpapers = await SystemWallpaper.installed()
    }
}
