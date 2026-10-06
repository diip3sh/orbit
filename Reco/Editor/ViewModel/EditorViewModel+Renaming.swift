//
//  EditorViewModel+Renaming.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation

extension EditorViewModel {

    /// Renames the recording's files to `name` (the video's, the telemetry's and the project's), saving pending
    /// edits first, and reopens it where it was. A refused name or a failed move shows its reason and changes nothing.
    func rename(to name: String) async {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard source != nil, name != RecordingRename.displayName(of: videoURL) else { return }
        playback.pause()
        let playhead = playheadSourceTime
        await flushSave()
        let old = videoURL
        do {
            videoURL = try await RecordingRenamer.rename(old, to: name)
        } catch {
            fail(.renameFailed(error))
            return
        }
        onRename?(old, videoURL)
        // The player's asset is of the old path
        await load(reloadingAt: playhead)
    }

    /// Writes the project now, instead of when edits settle.
    func flushSave() async {
        autosave?.cancel()
        await autosave?.value
        await save()
    }
}
