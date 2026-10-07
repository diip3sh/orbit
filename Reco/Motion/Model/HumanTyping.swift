//
//  HumanTyping.swift
//  Reco
//

import Foundation

/// How a person types into a field, as the film the user approved had it (spec 0012, L0, after New
/// Raycast): about 7–8 keys a second, uneven, slower into a new word; the page's results settling after
/// each word rather than flickering with every key; the caret solid while typing, then blinking softly.
nonisolated enum HumanTyping {

    /// When each character of `text` is typed, from `start`: 0.118 s apart, up to 0.035 s sooner or
    /// 0.045 s later at random, 0.11 s more for a space and 0.04 s more before one. "row level
    /// security" took 2.4 s (7.4 keys a second); Raycast's typing ran about 8.
    static func keyTimes(for text: String, from start: Double) -> [Double] {
        let characters = Array(text)
        var times: [Double] = []
        var time = start
        for (index, character) in characters.enumerated() {
            times.append(time)
            var step = 0.118 + (jitter(index, of: text) * 0.08 - 0.035)
            if character == " " {
                step += 0.11
            }
            if index + 1 < characters.count, characters[index + 1] == " " {
                step += 0.04
            }
            time += step
        }
        return times
    }

    /// How long after a word's last key its results show: a search settling, not one per key.
    static let settleDelay = 0.22

    /// The lengths of `text` at which a word ends: "row level security" settles at 3, 9 and 18.
    static func settledLengths(of text: String) -> [Int] {
        let characters = Array(text)
        return characters.indices.filter { characters[$0] != " " && ($0 + 1 == characters.count || characters[$0 + 1] == " ") }.map { $0 + 1 }
    }

    /// The caret's opacity at `time`: none before `since` (its last key, or when it appeared), solid
    /// for 0.5 s after, then on and off every 0.53 s with 0.08 s fades, as macOS and Raycast's film do.
    static func caretOpacity(at time: Double, since: Double) -> Double {
        guard time >= since else { return 0 }
        let blinking = time - since - 0.5
        guard blinking >= 0 else { return 1 }
        let phase = blinking.truncatingRemainder(dividingBy: 1.06)
        if phase < 0.53 {
            return phase > 0.45 ? smoothstep((0.53 - phase) / 0.08) : 1
        }
        return smoothstep((phase - 0.98) / 0.08)
    }

    /// The share of a field's growth `elapsed` seconds after its results came: a critically damped
    /// spring at 16 rad/s, 95 % there in 0.3 s, as the film's results panel opened.
    static func growth(after elapsed: Double) -> Double {
        guard elapsed > 0 else { return 0 }
        return 1 - (1 + 16 * elapsed) * exp(-16 * elapsed)
    }

    /// A share in 0…1, the same for the same character of the same text whenever it's typed (FNV-1a of
    /// the text and the index, so it doesn't change between launches as `Hasher` would).
    private static func jitter(_ index: Int, of text: String) -> Double {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in Array(text.utf8) + withUnsafeBytes(of: UInt64(index).littleEndian, Array.init) {
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        return Double(hash >> 11) / Double(1 << 53)
    }

    private static func smoothstep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}
