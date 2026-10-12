//
//  BackgroundAudioLoader.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import AVFoundation
import Foundation

/// Opens the music chosen for under the video. Bookmarks are made by ``BackgroundImageLoader/bookmark(for:)``, which
/// works for any file.
nonisolated enum BackgroundAudioLoader {

    /// The file `bookmark` opens, or `nil` when it's gone or has no audio track. Access to it stays on: the player and
    /// an export stream the file while the window is open, and the editor ends it when that closes.
    @concurrent
    static func url(from bookmark: Data) async -> URL? {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            return nil
        }
        // Not a failure when false: unsandboxed, a plain file needs no scope
        _ = url.startAccessingSecurityScopedResource()
        guard let tracks = try? await AVURLAsset(url: url).loadTracks(withMediaType: .audio), !tracks.isEmpty else {
            url.stopAccessingSecurityScopedResource()
            return nil
        }
        return url
    }
}
