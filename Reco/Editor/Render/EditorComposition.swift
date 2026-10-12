//
//  EditorComposition.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import AVFoundation

/// What the player plays and export writes, built by ``CompositionBuilder``.
///
/// The asset changes only with the cuts; the video composition and the mix are replaced in place.
///
/// `@unchecked`: the AVFoundation objects aren't annotated, and nobody changes them once an export has them; it
/// reads them on its own queue.
nonisolated struct EditorComposition: @unchecked Sendable {

    /// The recording's kept ranges, end to end.
    let asset: AVComposition

    var videoComposition: AVVideoComposition
    var audioMix: AVAudioMix

    /// The files the asset holds besides the recording's. A new one is a new asset.
    let extraAudio: ExtraAudio
}
