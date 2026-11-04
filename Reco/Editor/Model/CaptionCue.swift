//
//  CaptionCue.swift
//  Reco
//

import Foundation

/// A caption on screen for a while (spec 0023, section 1). Times are source seconds, so cuts and speeds never
/// invalidate it.
nonisolated struct CaptionCue: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()

    /// Moving or resizing the cue carries its words along, so the lane's operations keep them in step.
    var range: Range<Double> {
        didSet {
            let scale = oldValue.isEmpty ? 1 : (range.upperBound - range.lowerBound) / (oldValue.upperBound - oldValue.lowerBound)
            let start = range.lowerBound
            let retimed = { (time: Double) in start + (time - oldValue.lowerBound) * scale }
            for index in words.indices {
                words[index].range = retimed(words[index].range.lowerBound)..<retimed(words[index].range.upperBound)
            }
        }
    }

    var text: String

    /// In order, inside ``range``.
    var words: [CaptionWord]

    /// This cue saying `text`. The same number of words keeps every word's times, since a corrected word was still
    /// said then; another number spreads them over the cue by their lengths. Words that didn't change keep their
    /// confidence. `nil` when `text` is blank.
    func editing(text: String) -> CaptionCue? {
        let tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return nil }
        var cue = self
        cue.text = tokens.joined(separator: " ")
        cue.words = tokens.count == words.count
            ? zip(tokens, words).map { token, word in
                CaptionWord(text: token, range: word.range, confidence: token == word.text ? word.confidence : 1)
            }
            : Self.spreading(tokens, over: range, keeping: words)
        return cue
    }

    /// `tokens` one after the other over `range`, each taking a share of it by its length.
    private static func spreading(_ tokens: [String], over range: Range<Double>, keeping words: [CaptionWord]) -> [CaptionWord] {
        let total = tokens.reduce(0) { $0 + $1.count }
        let duration = range.upperBound - range.lowerBound
        var characters = 0
        return tokens.enumerated().map { index, token in
            let start = range.lowerBound + duration * Double(characters) / Double(total)
            characters += token.count
            // The last ends exactly on the cue's end, whatever the rounding
            let end = index == tokens.count - 1 ? range.upperBound : range.lowerBound + duration * Double(characters) / Double(total)
            return CaptionWord(text: token, range: start..<end, confidence: words.first { $0.text == token }?.confidence ?? 1)
        }
    }
}

/// A captions lane's clip.
nonisolated extension CaptionCue: TimelineClip {
    static var minimumDuration: Double { 0.25 }
}
