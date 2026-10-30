//
//  CaptionSegmenter.swift
//  Reco
//

import Foundation

/// Turns timed words into captions short enough to read.
nonisolated enum CaptionSegmenter {

    /// About two lines at the default size, which is as much as a caption draws comfortably.
    static let maximumCharacters = 70

    /// A caption longer than this goes unread before it ends.
    static let maximumDuration = 6.0

    /// A silence this long, in seconds, ends a caption, so it doesn't sit on screen with nothing being said.
    static let pause = 0.7

    /// A caption stays at least this long, when the next one leaves room, so a single word can be read.
    static let minimumDuration = 1.0

    /// A sentence ends a caption once it has this many characters, so "Yes." doesn't flash by alone.
    static let shortestSentence = 16

    private static let sentenceEnds: Set<Character> = [".", "?", "!", "…", "。", "？", "！"]

    /// Adds what a transcriber said next to `words`, in its order. Text without a time or with no letters or digits
    /// (punctuation, in the languages that time it separately) joins the word before it. `text` keeps the space
    /// before it where the language has one, which ``cues(from:)`` needs.
    static func append(text: String, range: Range<Double>?, confidence: Double?, to words: inout [CaptionWord]) {
        guard !text.allSatisfy(\.isWhitespace) else { return }
        guard let range, text.contains(where: { $0.isLetter || $0.isNumber }) else {
            if let last = words.indices.last {
                words[last].text += text
                if let range {
                    words[last].range = words[last].range.lowerBound..<max(words[last].range.upperBound, range.upperBound)
                }
            }
            return
        }
        words.append(CaptionWord(text: text, range: range, confidence: confidence ?? 1))
    }

    /// The captions for `words`, in time order and apart. Each word's text may start with the space before it; the
    /// cues' words don't, and a cue's text keeps those spaces, so languages without any stay as they are.
    static func cues(from words: [CaptionWord]) -> [CaptionCue] {
        var groups: [[CaptionWord]] = []
        for word in words.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) where !word.range.isEmpty {
            if let group = groups.last, !endsCue(group, before: word) {
                groups[groups.count - 1].append(word)
            } else {
                groups.append([word])
            }
        }
        return groups.indices.map { index in
            let group = groups[index]
            let start = group[0].range.lowerBound
            let next = index + 1 < groups.count ? groups[index + 1][0].range.lowerBound : Double.infinity
            let spoken = group.map(\.range.upperBound).max() ?? start
            let end = max(min(max(spoken, start + minimumDuration), next), start + CaptionCue.minimumDuration)
            return CaptionCue(
                range: start..<end,
                text: text(of: group),
                words: group.map {
                    CaptionWord(
                        text: $0.text.trimmingCharacters(in: .whitespacesAndNewlines),
                        range: min($0.range.lowerBound, end)..<min($0.range.upperBound, end),
                        confidence: $0.confidence
                    )
                }
            )
        }
    }

    private static func endsCue(_ group: [CaptionWord], before word: CaptionWord) -> Bool {
        guard let last = group.last else { return false }
        let characters = text(of: group).count
        return word.range.lowerBound - last.range.upperBound >= pause
            || word.range.upperBound - group[0].range.lowerBound > maximumDuration
            || characters + word.text.count > maximumCharacters
            || (characters >= shortestSentence && last.text.last.map(sentenceEnds.contains) == true)
    }

    private static func text(of group: [CaptionWord]) -> String {
        group.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
