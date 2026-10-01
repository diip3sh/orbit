//
//  PlaybackController.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation

/// Plays the recording in the editor: play/pause, frame-accurate seeking and frame stepping.
///
/// The playhead is only observed while paused. During playback ``currentTime`` reads the player,
/// so views that show it read it inside a `TimelineView` and a tick redraws nothing else.
@MainActor
@Observable
final class PlaybackController {

    @ObservationIgnored let player = AVPlayer()

    private(set) var isPlaying = false

    /// The playhead while paused: the start of the frame shown, or of the latest seek target.
    private(set) var pausedTime: Double = 0

    @ObservationIgnored private var frames = FrameGrid(frameRate: 60, duration: 0)
    @ObservationIgnored private var timescale: CMTimeScale = 600
    @ObservationIgnored private var pendingSeek: CMTime?
    @ObservationIgnored private var isSeeking = false
    @ObservationIgnored private var endObserver: (any NSObjectProtocol)?

    /// The playhead in seconds. Not observed during playback.
    var currentTime: Double {
        isPlaying ? player.currentTime().seconds : pausedTime
    }

    /// Plays `composition`, paused on the frame at output time `time`. Replaces what was playing.
    /// - Parameter frames: The output's frames.
    func load(_ composition: EditorComposition, frames: FrameGrid, timescale: CMTimeScale, at time: Double) {
        pause()
        self.frames = frames
        self.timescale = timescale

        let item = AVPlayerItem(asset: composition.asset)
        item.videoComposition = composition.videoComposition
        item.audioMix = composition.audioMix
        // A seek completes once its frame is drawn, so scrubbing never shows a bare source frame
        item.seekingWaitsForVideoCompositionRendering = true
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        player.replaceCurrentItem(with: item)
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.didPlayToEnd()
            }
        }
        seek(toFrame: frames.frame(at: time))
    }

    /// Plays from the playhead, or from the start when it's on the last frame.
    func togglePlay() {
        guard !isPlaying else {
            pause()
            return
        }

        // Seeks right away rather than coalesced: playing from the end would end the item again first
        if frames.frame(at: pausedTime) == frames.lastFrame {
            pendingSeek = nil
            pausedTime = 0
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        player.play()
        isPlaying = true
    }

    func pause() {
        guard isPlaying else { return }
        player.pause()
        isPlaying = false
        pausedTime = frames.time(ofFrame: frames.frame(at: player.currentTime().seconds))
    }

    /// Pauses and shows the frame at `time`.
    func seek(to time: Double) {
        pause()
        seek(toFrame: frames.frame(at: time))
    }

    /// Pauses and moves the playhead by `count` frames, backwards when negative.
    func step(by count: Int) {
        pause()
        let current = frames.frame(at: pausedTime)
        let target = min(max(current + count, 0), frames.lastFrame)

        // Stepping decodes only the next frame, where a seek decodes from the previous keyframe.
        // Behind a pending seek, the player's position isn't the playhead yet, so seek instead.
        if isSeeking {
            seek(toFrame: target)
        } else {
            player.currentItem?.step(byCount: target - current)
            pausedTime = frames.time(ofFrame: target)
        }
    }

    /// Draws frames with a new render plan. While paused, the frame on screen is redrawn.
    func setVideoComposition(_ videoComposition: AVVideoComposition) {
        player.currentItem?.videoComposition = videoComposition
        if !isPlaying {
            seek(toFrame: frames.frame(at: pausedTime))
        }
    }

    func setAudioMix(_ audioMix: AVAudioMix) {
        player.currentItem?.audioMix = audioMix
    }

    /// Releases the player item and its decoders, when the window closes.
    func release() {
        player.pause()
        isPlaying = false
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        player.replaceCurrentItem(with: nil)
    }

    // MARK: - Private

    /// Seeks exactly to a frame's start. At most one seek is in flight, and the latest request
    /// replaces a pending one (Apple QA1820), so scrubbing never queues up stale frames.
    private func seek(toFrame frame: Int) {
        pausedTime = frames.time(ofFrame: frame)
        pendingSeek = CMTime(seconds: pausedTime, preferredTimescale: timescale)
        guard !isSeeking else { return }

        isSeeking = true
        Task {
            while let target = pendingSeek {
                pendingSeek = nil
                await player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
            }
            isSeeking = false
        }
    }

    /// Parks the player on the last frame's start, where the playhead is, so stepping back from it
    /// counts from that frame rather than from the end of the item.
    private func didPlayToEnd() {
        isPlaying = false
        seek(toFrame: frames.lastFrame)
    }
}
