//
//  PlayerLayerView.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation
import SwiftUI

/// Shows the player's video, letterboxed, without system playback controls.
struct PlayerLayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> LayerView {
        let view = LayerView()
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ nsView: LayerView, context: Context) {
        nsView.playerLayer.player = player
    }

    static func dismantleNSView(_ nsView: LayerView, coordinator: ()) {
        nsView.playerLayer.player = nil
    }

    /// A view hosting an `AVPlayerLayer`, which resizes with it.
    final class LayerView: NSView {
        let playerLayer = AVPlayerLayer()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            playerLayer.backgroundColor = .black
            layer = playerLayer
            wantsLayer = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
