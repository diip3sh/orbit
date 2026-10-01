//
//  PlayerLayerView.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import AVFoundation
import SwiftUI

/// Shows the player's video, letterboxed, without system playback controls, clipped to rounded
/// corners. Transparent where there's no video, so what's behind shows.
struct PlayerLayerView: NSViewRepresentable {
    let player: AVPlayer
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> LayerView {
        let view = LayerView()
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ nsView: LayerView, context: Context) {
        nsView.playerLayer.player = player
        nsView.playerLayer.cornerRadius = cornerRadius
    }

    static func dismantleNSView(_ nsView: LayerView, coordinator: ()) {
        nsView.playerLayer.player = nil
    }

    /// A view hosting an `AVPlayerLayer`, which resizes with it.
    final class LayerView: NSView {
        let playerLayer = AVPlayerLayer()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            playerLayer.cornerCurve = .continuous
            playerLayer.masksToBounds = true
            layer = playerLayer
            wantsLayer = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
