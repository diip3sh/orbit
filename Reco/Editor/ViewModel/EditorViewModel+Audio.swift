//
//  EditorViewModel+Audio.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation
import OSLog

extension EditorViewModel {

    /// Whether a rebuild must write the click sounds first: they're wanted and nothing has asked for them yet.
    var needsNewAudioFiles: Bool {
        project.audio.addsAudio && clickSoundFile == nil
    }

    /// The files to add to the recording's audio. The click sounds are written the first time `audio` wants them, and
    /// are there from then on (silent at volume 0), so changing the volume never makes a new player item.
    func extraAudio(for audio: AudioMixSettings, source: EditorSource) async -> ExtraAudio {
        if clickSoundFile == nil, audio.addsAudio {
            let onsets = source.telemetry.map { ClickSound.onsets(of: $0.clicks) } ?? []
            let frameCount = Int((source.duration * ClickSound.sampleRate).rounded(.up)) + Int(0.1 * ClickSound.sampleRate)
            let url = ClickSoundWriter.folder.appending(path: "\(UUID().uuidString).caf")
            let name = videoURL.lastPathComponent
            clickSoundFile = Task {
                guard !onsets.isEmpty else { return nil }
                do {
                    try await ClickSoundWriter.write(onsets: onsets, frameCount: frameCount, to: url)
                    return url
                } catch {
                    self.logger.error("\(name): no click sounds: \(error.localizedDescription)")
                    return nil
                }
            }
        }
        guard let file = clickSoundFile else { return ExtraAudio() }
        return ExtraAudio(clicks: await file.value)
    }

    /// Deletes the files ``extraAudio(for:source:)`` wrote. Called when the window closes.
    func releaseAudioFiles() async {
        guard let file = clickSoundFile else { return }
        clickSoundFile = nil
        guard let url = await file.value else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
