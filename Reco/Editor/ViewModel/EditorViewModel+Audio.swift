//
//  EditorViewModel+Audio.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import CoreMedia
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

    /// Whether a rebuild must open files first: the click sounds are wanted and nothing has asked for them yet, the
    /// music isn't the one the last composition was built with, or other tracks are enhanced than in it. Volume and
    /// mute are the mix's alone.
    var needsNewAudioFiles: Bool {
        (project.audio.clickVolume > 0 && clickSoundFile == nil)
            || project.audio.background?.bookmark != backgroundAudio?.bookmark
            || Set(enhancedTrackIDs(for: project.audio)) != Set(composition.map { Array($0.extraAudio.enhanced.keys) } ?? [])
    }

    /// The files to add to the recording's audio. The click sounds are written the first time `audio` wants them, and
    /// are there from then on (silent at volume 0), so changing the volume never makes a new player item. The parts
    /// `timeMap` speeds up and the tracks `audio` enhances are rendered once each.
    func extraAudio(for audio: AudioMixSettings, source: EditorSource, timeMap: TimeMap) async -> ExtraAudio {
        var extra = ExtraAudio(background: await backgroundAudioURL(for: audio.background?.bookmark))
        extra.enhanced = await enhancedVoiceFiles(for: audio)
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
        extra.clicks = await clickSoundFile?.value
        extra.fastParts = await fastPartFiles(for: timeMap, source: source, clicks: extra.clicks, enhanced: extra)
        return extra
    }

    /// Deletes the files ``extraAudio(for:source:)`` wrote and lets go of the music. Called when the window closes.
    func releaseAudioFiles() async {
        let music = backgroundAudio
        backgroundAudio = nil
        await music?.url.value?.stopAccessingSecurityScopedResource()
        let files = fastPartAudio.values.map(\.file) + Array(enhancedVoice.values) + (clickSoundFile.map { [$0] } ?? [])
        fastPartAudio = [:]
        enhancedVoice = [:]
        clickSoundFile = nil
        await Self.delete(files)
    }

    // MARK: - Private

    /// The track IDs `audio` enhances, of the recording's.
    private func enhancedTrackIDs(for audio: AudioMixSettings) -> [CMPersistentTrackID] {
        let trackIDs = source?.audioTrackIDs ?? []
        return audio.enhancedTracks.filter { $0 < trackIDs.count }.map { trackIDs[$0] }
    }

    /// The enhanced files of the tracks `audio` enhances, rendering the ones no rebuild has asked for yet, side by side.
    private func enhancedVoiceFiles(for audio: AudioMixSettings) async -> [CMPersistentTrackID: URL?] {
        let trackIDs = enhancedTrackIDs(for: audio)
        let videoURL = videoURL
        for trackID in trackIDs where enhancedVoice[trackID] == nil {
            let url = VoiceEnhancer.folder.appending(path: "\(UUID().uuidString).caf")
            // Unstructured and stored before anything is awaited, as the music is: another rebuild finds it meanwhile
            enhancedVoice[trackID] = Task {
                do {
                    try await VoiceEnhancer.render(trackID: trackID, from: videoURL, to: url)
                    return url
                } catch {
                    self.logger.error("\(videoURL.lastPathComponent): no enhanced voice for track \(trackID): \(error.localizedDescription)")
                    return nil
                }
            }
        }
        var files: [CMPersistentTrackID: URL?] = [:]
        for trackID in trackIDs {
            files[trackID] = .some(await enhancedVoice[trackID]?.value)
        }
        return files
    }

    /// The sped-up audio of the recording's tracks (from their enhanced files, where there are) and the click sounds
    /// for each part of `timeMap` at another speed, rendering the ones no rebuild has asked for from that file yet, side
    /// by side. A part rendered from another file is replaced, and the old one deleted.
    private func fastPartFiles(
        for timeMap: TimeMap, source: EditorSource, clicks: URL?, enhanced: ExtraAudio
    ) async -> [SpeedAudio.Part: URL] {
        let clickTrackID = CompositionBuilder.extraTrackID(1, for: source)
        let parts = SpeedAudio.parts(of: timeMap, trackIDs: source.audioTrackIDs + (clicks == nil ? [] : [clickTrackID]))
        let videoURL = videoURL
        for part in parts {
            let file = part.trackID == clickTrackID ? clicks : enhanced.enhancedFile(for: part.trackID) ?? videoURL
            guard let file, fastPartAudio[part]?.source != file else { continue }
            if let stale = fastPartAudio[part] {
                Task { await Self.delete([stale.file]) }
            }
            let trackID = part.trackID == clickTrackID || file != videoURL ? nil : part.trackID
            let url = SpeedAudio.folder.appending(path: "\(UUID().uuidString).caf")
            // Unstructured and stored before anything is awaited, as the music is: another rebuild finds it meanwhile
            fastPartAudio[part] = (file, Task {
                do {
                    try await SpeedAudio.render(part, from: file, trackID: trackID, to: url)
                    return url
                } catch {
                    self.logger.error("\(videoURL.lastPathComponent): no audio at \(part.rate)×: \(error.localizedDescription)")
                    return nil
                }
            })
        }
        var files: [SpeedAudio.Part: URL] = [:]
        for part in parts {
            files[part] = await fastPartAudio[part]?.file.value
        }
        return files
    }

    /// Removes the files `tasks` wrote, once they have.
    private static func delete(_ tasks: [Task<URL?, Never>]) async {
        for task in tasks {
            if let url = await task.value {
                try? FileManager.default.removeItem(at: url)
            }
        }
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
