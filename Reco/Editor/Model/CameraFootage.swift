//
//  CameraFootage.swift
//  Reco
//

import AVFoundation

/// The camera's own video beside a recording, `<name>.camera.mov`, and how it lines up with it.
nonisolated struct CameraFootage: Sendable {

    /// What a camera file's name ends in, before its extension. The Library leaves such movies out.
    static let nameSuffix = ".camera"

    let url: URL
    let asset: AVURLAsset
    let trackID: CMPersistentTrackID

    /// The video track's extent in the file.
    let timeRange: CMTimeRange

    /// The frames' size as they show, turned by ``orientation``.
    let displaySize: CGSize

    let orientation: CGImagePropertyOrientation

    /// Where the file starts on the recording's timeline, in seconds: negative when the camera was running first.
    let offset: Double

    /// Whether ``offset`` was read; without a sidecar the footage starts with the recording, which may be out of sync.
    let hasRecordedOffset: Bool

    /// The camera movie for a recording: same folder and base name, whatever the recording's container.
    static func movieURL(for videoURL: URL) -> URL {
        videoURL.deletingPathExtension().appendingPathExtension("camera").appendingPathExtension("mov")
    }

    /// The offset's file for a recording.
    static func sidecarURL(for videoURL: URL) -> URL {
        videoURL.deletingPathExtension().appendingPathExtension("camera").appendingPathExtension("json")
    }

    /// The turn a video track's `transform` asks for; other transforms, which cameras and phones don't write, show as is.
    static func orientation(of transform: CGAffineTransform) -> CGImagePropertyOrientation {
        switch (transform.a, transform.b, transform.c, transform.d) {
        case (0, 1, -1, 0): .right
        case (0, -1, 1, 0): .left
        case (-1, 0, 0, -1): .down
        default: .up
        }
    }
}
