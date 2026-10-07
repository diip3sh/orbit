//
//  ClickSound.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation

/// The click the editor can play at every mouse press: one short sound, placed on the recording's timeline.
nonisolated enum ClickSound {

    static let sampleRate = 48_000.0

    /// 20 ms of a mouse click: a ticking body (2.4 kHz, decaying over 4 ms) over a brighter edge (5.2 kHz, over
    /// 1.5 ms). Synthesised, so there is no licensed asset; the numbers were picked by ear on 2026-10-07. It starts
    /// at a zero crossing, so the first sample is silent and the click can't pop.
    static let samples: [Float] = (0..<Int(0.02 * sampleRate)).map { index in
        let time = Double(index) / sampleRate
        let body = 0.6 * exp(-time / 0.004) * sin(2 * .pi * 2_400 * time)
        let edge = 0.4 * exp(-time / 0.0015) * sin(2 * .pi * 5_200 * time)
        return Float(body + edge)
    }

    /// The sample at which each press sounds, on the recording's timeline: every button's press, not its release.
    /// - Parameter clicks: Sorted by time.
    static func onsets(of clicks: [InputTelemetry.Click]) -> [Int] {
        clicks.filter(\.isDown).map { max(Int(($0.time * sampleRate).rounded()), 0) }
    }

    /// Adds the clicks that sound within `buffer`, which holds the recording's samples from `frame` on. Clicks that
    /// overlap add up, and the sum is kept within ±1.
    /// - Parameter onsets: Sorted.
    static func mix(onsets: [Int], into buffer: UnsafeMutableBufferPointer<Float>, startingAt frame: Int) {
        let first = onsets.partitioningIndex { $0 > frame - samples.count }
        for onset in onsets[first...] {
            guard onset < frame + buffer.count else { break }
            for index in max(frame - onset, 0)..<min(samples.count, frame + buffer.count - onset) {
                let target = onset + index - frame
                buffer[target] = min(max(buffer[target] + samples[index], -1), 1)
            }
        }
    }
}
