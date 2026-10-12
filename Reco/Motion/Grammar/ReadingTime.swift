//
//  ReadingTime.swift
//  Reco
//

import Foundation

/// How long text has to stay to be read. The reference films hold a title 0.9–2.5 s (median 2.0) and
/// show 1.5–8.7 words a second while it's held (median 3.1).
nonisolated enum ReadingTime {

    static let shortestHold = 0.9
    static let wordsPerSecond = 3.1

    /// A word alone is read at a glance: Lovable's end words ("Chat", "with") held 0.7 s each, two beats at 170 BPM.
    static let oneWordHold = 0.6

    /// Seconds `text` must be held once it's all shown.
    static func hold(for text: String) -> Double {
        let count = words(in: text)
        return count == 1 ? oneWordHold : max(shortestHold, Double(count) / wordsPerSecond)
    }

    static func words(in text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..., options: .byWords) { _, _, _, _ in count += 1 }
        return count
    }
}
