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
struct EditorComposition {

    /// The recording's kept ranges, end to end.
    let asset: AVComposition

    var videoComposition: AVVideoComposition
    var audioMix: AVAudioMix
}
