//
//  EditorViewModel+Audio.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation
import OSLog

extension EditorViewModel {

    /// Makes the file at `url`, chosen by the user, the music under the video. A new file keeps the volume and mute of
    /// the one it replaces.
    func setBackgroundAudio(_ url: URL) {
        do {
            let bookmark = try BackgroundImageLoader.bookmark(for: url)
            edit("Background Audio") {
                var background = BackgroundAudio(bookmark: bookmark, name: url.deletingPathExtension().lastPathComponent)
                background.track = $0.audio.background?.track ?? background.track
                $0.audio.background = background
            }
        } catch {
            logger.error("No bookmark for \(url.lastPathComponent): \(error.localizedDescription)")
            fail(.unreadableBackgroundAudio)
        }
    }

    func removeBackgroundAudio() {
        edit("Remove Background Audio") { $0.audio.background = nil }
    }

    /// Whether a rebuild must open files first: the click sounds are wanted and nothing has asked for them yet, or the
    /// music isn't the one the last composition was built with. Volume and mute are the mix's alone.
    var needsNewAudioFiles: Bool {
        (project.audio.clickVolume > 0 && clickSoundFile == nil) || project.audio.background?.bookmark != backgroundAudio?.bookmark
    }

    /// The files to add to the recording's audio. The click sounds are written the first time `audio` wants them, and
    /// are there from then on (silent at volume 0), so changing the volume never makes a new player item. The parts
    /// `timeMap` speeds up are rendered once each.
    func extraAudio(for audio: AudioMixSettings, source: EditorSource, timeMap: TimeMap) async -> ExtraAudio {
        let background = await backgroundAudioURL(for: audio.background?.bookmark)
        if clickSoundFile == nil, audio.clickVolume > 0 {
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
        let clicks = await clickSoundFile?.value
        return ExtraAudio(clicks: clicks, background: background, fastParts: await fastPartFiles(for: timeMap, source: source, clicks: clicks))
    }

    /// Deletes the files ``extraAudio(for:source:)`` wrote and lets go of the music. Called when the window closes.
    func releaseAudioFiles() async {
        let music = backgroundAudio
        backgroundAudio = nil
        await music?.url.value?.stopAccessingSecurityScopedResource()
        let files = Array(fastPartAudio.values) + (clickSoundFile.map { [$0] } ?? [])
        fastPartAudio = [:]
        clickSoundFile = nil
        for file in files {
            if let url = await file.value {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Private

    /// The sped-up audio of the recording's tracks and the click sounds for each part of `timeMap` at another speed,
    /// rendering the ones no rebuild has asked for yet, side by side.
    private func fastPartFiles(for timeMap: TimeMap, source: EditorSource, clicks: URL?) async -> [SpeedAudio.Part: URL] {
        let clickTrackID = CompositionBuilder.extraTrackID(1, for: source)
        let parts = SpeedAudio.parts(of: timeMap, trackIDs: source.audioTrackIDs + (clicks == nil ? [] : [clickTrackID]))
        let videoURL = videoURL
        for part in parts where fastPartAudio[part] == nil {
            let file = part.trackID == clickTrackID ? clicks : videoURL
            let trackID = part.trackID == clickTrackID ? nil : part.trackID
            let url = SpeedAudio.folder.appending(path: "\(UUID().uuidString).caf")
            // Unstructured and stored before anything is awaited, as the music is: another rebuild finds it meanwhile
            fastPartAudio[part] = Task {
                guard let file else { return nil }
                do {
                    try await SpeedAudio.render(part, from: file, trackID: trackID, to: url)
                    return url
                } catch {
                    self.logger.error("\(videoURL.lastPathComponent): no audio at \(part.rate)×: \(error.localizedDescription)")
                    return nil
                }
            }
        }
        var files: [SpeedAudio.Part: URL] = [:]
        for part in parts {
            files[part] = await fastPartAudio[part]?.value
        }
        return files
    }

    /// The music file `bookmark` opens, opened once per bookmark: a different one lets go of the last.
    private func backgroundAudioURL(for bookmark: Data?) async -> URL? {
        if backgroundAudio?.bookmark != bookmark {
            let previous = backgroundAudio
            // Set before anything is awaited, so a second rebuild meanwhile finds it instead of opening the file again.
            // Unstructured, so cancelling this rebuild doesn't leave the next one a task that never finished.
            backgroundAudio = bookmark.map { file in (file, Task { await BackgroundAudioLoader.url(from: file) }) }
            await previous?.url.value?.stopAccessingSecurityScopedResource()
            if bookmark != nil, await backgroundAudio?.url.value == nil {
                fail(.unreadableBackgroundAudio)
            }
        }
        return await backgroundAudio?.url.value
    }
}
