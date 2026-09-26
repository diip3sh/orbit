//
//  EditorSourceLoader.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation

/// Loads a recording for the editor, off the main actor: its video's properties and its telemetry.
nonisolated enum EditorSourceLoader {

    /// Throws ``EditorError`` when the video can't be opened. Missing or unreadable telemetry
    /// doesn't throw: the editor opens without telemetry-driven features and says why.
    @concurrent
    static func load(videoURL: URL) async throws -> EditorSource {
        let asset = AVURLAsset(url: videoURL)
        do {
            guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                throw EditorError.noVideoTrack
            }
            let duration = try await asset.load(.duration)
            let (naturalSize, frameRate, timescale) = try await track.load(.naturalSize, .nominalFrameRate, .naturalTimeScale)
            let (telemetry, telemetryError) = loadTelemetry(for: videoURL)

            return EditorSource(
                asset: asset,
                duration: duration.seconds,
                naturalSize: naturalSize,
                frameRate: Double(frameRate),
                timescale: timescale,
                telemetry: telemetry,
                telemetryError: telemetryError
            )
        } catch let error as EditorError {
            throw error
        } catch {
            throw EditorError.unreadableVideo(error)
        }
    }

    /// The recording's telemetry, or why there is none.
    static func loadTelemetry(for videoURL: URL) -> (InputTelemetry?, EditorError?) {
        let data: Data
        do {
            data = try Data(contentsOf: InputTelemetry.sidecarURL(for: videoURL))
        } catch CocoaError.fileReadNoSuchFile {
            return (nil, .noTelemetry)
        } catch {
            return (nil, .unreadableTelemetry(error))
        }

        do {
            return (try JSONDecoder().decode(InputTelemetry.self, from: data), nil)
        } catch {
            return (nil, .unreadableTelemetry(error))
        }
    }
}
