//
//  SystemAudioStream.swift
//  Reco
//
//  Created by Joshua Sattler on 30.08.26.
//

import AppKit
import Foundation
import OSLog
@preconcurrency import ScreenCaptureKit

/// A second `SCStream` that captures system audio independently of the selected content.
///
/// Audio is a stream output, so a single stream scopes it to whatever the *video* filter
/// selected: a window capture would only ever record its own app's audio, and an application
/// capture only that app's. This stream pairs a full-display filter with a throwaway 2x2
/// video configuration so system audio stays complete no matter what was selected for video.
@MainActor
final class SystemAudioStream {

    // MARK: - Properties

    private var stream: SCStream?

    /// The identity of the running stream.
    ///
    /// `SCStreamDelegate` callbacks are not main-actor isolated and `SCStream` is not
    /// `Sendable`, so the stream cannot be compared after hopping to the main actor. This
    /// mirror is written only from the main actor and read only for identity comparison.
    nonisolated(unsafe) private var streamIdentity: ObjectIdentifier?

    /// Receives and drops the video frames the stream produces regardless.
    private let videoOutput = DiscardedVideoOutput()

    /// The queue the discarded frames are delivered on, kept off the audio queue so a
    /// stalled frame can never delay an audio buffer.
    private let videoSampleQueue = DispatchQueue(label: "com.diip3sh.reco.systemAudioVideoQueue", qos: .utility)

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Reco",
        category: "SystemAudioStream"
    )

    /// Whether the stream is currently running.
    var isRunning: Bool { stream != nil }

    // MARK: - Lifecycle

    /// Starts capturing system audio.
    /// - Parameters:
    ///   - output: The stream output receiving the audio sample buffers.
    ///   - delegate: The delegate notified when the stream stops.
    ///   - sampleQueue: The queue the audio buffers are delivered on.
    func start(
        output: SCStreamOutput,
        delegate: SCStreamDelegate,
        sampleQueue: DispatchQueue
    ) async throws {
        guard stream == nil else { return }

        let content = try await SCShareableContent.current

        guard let display = mainDisplay(in: content) else {
            throw CaptureError.failedToCreateStream
        }

        // Audio is not display-scoped, so any connected display yields full system audio.
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let newStream = SCStream(filter: filter, configuration: makeConfiguration(), delegate: delegate)

        try newStream.addStreamOutput(output, type: .audio, sampleHandlerQueue: sampleQueue)

        // SCStream renders video whether or not anything asks for it, and logs an error for
        // every frame it cannot hand to a `.screen` output. Take the frames and drop them.
        try newStream.addStreamOutput(videoOutput, type: .screen, sampleHandlerQueue: videoSampleQueue)

        try await newStream.startCapture()

        stream = newStream
        streamIdentity = ObjectIdentifier(newStream)
        logger.info("Dedicated system audio stream started on display \(display.displayID)")
    }

    /// Stops the stream, if it is running.
    func stop() async {
        guard let stream else { return }
        self.stream = nil
        streamIdentity = nil

        do {
            try await stream.stopCapture()
            logger.info("Dedicated system audio stream stopped")
        } catch {
            logger.error("Failed to stop system audio stream: \(error.localizedDescription)")
        }
    }

    /// Whether the given stream is this stream.
    nonisolated func owns(_ stream: SCStream) -> Bool {
        streamIdentity == ObjectIdentifier(stream)
    }

    /// Clears the stream reference after it stopped on its own.
    func handleStoppedExternally() {
        stream = nil
        streamIdentity = nil
    }

    // MARK: - Configuration

    /// The video side of the stream is unused, so it is configured as small and as slow as
    /// ScreenCaptureKit accepts while still delivering audio.
    private func makeConfiguration() -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 48000
        config.channelCount = 2
        config.excludesCurrentProcessAudio = true
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.showsCursor = false
        config.queueDepth = 3
        return config
    }

    /// The display to attach the audio filter to, preferring the one the user is on.
    private func mainDisplay(in content: SCShareableContent) -> SCDisplay? {
        let mainDisplayID = NSScreen.main?
            .deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID

        if let mainDisplayID, let display = content.displays.first(where: { $0.displayID == mainDisplayID }) {
            return display
        }

        return content.displays.first
    }
}

// MARK: - Discarded Video Output

/// Absorbs the video frames of the audio-only stream.
///
/// `SCStream` has no audio-only mode: it always renders video, and logs
/// `stream output NOT found. Dropping frame` for every frame when no `.screen` output is
/// registered. The frames are 2x2 and arrive once per second, so consuming and discarding
/// them costs nothing.
private final class DiscardedVideoOutput: NSObject, SCStreamOutput {

    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        // Intentionally empty
    }
}
