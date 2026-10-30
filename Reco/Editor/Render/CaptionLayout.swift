//
//  CaptionLayout.swift
//  Reco
//

import CoreText
import Foundation

/// A caption's text laid out in its box: at most two lines, as even as its word breaks allow, shrunk when even that
/// doesn't fit the width. Built once per render plan.
nonisolated struct CaptionLayout {

    /// A line of text and where its baseline starts, from the box's bottom-left corner.
    struct Line {
        let line: CTLine
        let origin: CGPoint
    }

    /// The box around the text, in pixels.
    let size: CGSize

    let lines: [Line]

    /// Where each word found in the text is, in whole pixels from the box's bottom-left corner.
    let wordRects: [CGRect]

    /// - Parameters:
    ///   - words: The words the text is made of, in order. One the text doesn't contain ends the rects there.
    ///   - fontSize: The size wanted, in pixels.
    ///   - maximumWidth: The widest the box can be.
    init(text: String, words: [String], fontSize: CGFloat, maximumWidth: CGFloat) {
        let wordRanges = Self.ranges(of: words, in: text)
        let split = Self.split(of: text, wordRanges: wordRanges, fontSize: fontSize, width: maximumWidth - 2 * Self.horizontalPadding(fontSize))
        let parts = split.map { [Self.substring(of: text, 0..<$0), Self.substring(of: text, $0..<text.utf16.count)] } ?? [text]
        let widest = parts.map { Self.width(of: Self.line($0, fontSize: fontSize)) }.max() ?? 0
        let available = maximumWidth - 2 * Self.horizontalPadding(fontSize)
        let size = widest > available ? (fontSize * available / widest * 0.99).rounded(.down) : fontSize

        let font = Self.font(size: size)
        let (ascent, descent) = (CTFontGetAscent(font), CTFontGetDescent(font))
        let lineHeight = ((ascent + descent) * 1.1).rounded(.up)
        let verticalPadding = (size * 0.3).rounded(.up)
        let drawn = parts.map { Self.line($0, fontSize: size) }
        let box = CGSize(
            width: ((drawn.map(Self.width).max() ?? 0) + 2 * Self.horizontalPadding(size)).rounded(.up),
            height: CGFloat(parts.count) * lineHeight + 2 * verticalPadding
        )
        let descentInLine = (lineHeight - ascent - descent) / 2 + descent
        let placed = drawn.enumerated().map { index, line in
            Line(
                line: line,
                origin: CGPoint(
                    x: ((box.width - Self.width(of: line)) / 2).rounded(),
                    y: verticalPadding + CGFloat(parts.count - 1 - index) * lineHeight + descentInLine
                )
            )
        }

        self.size = box
        lines = placed
        wordRects = wordRanges.map { range in
            let isSecond = split.map { range.lowerBound >= $0 } ?? false
            let line = placed[isSecond ? 1 : 0]
            let offset = isSecond ? split ?? 0 : 0
            let start = CTLineGetOffsetForStringIndex(line.line, range.lowerBound - offset, nil)
            let end = CTLineGetOffsetForStringIndex(line.line, range.upperBound - offset, nil)
            return CGRect(x: line.origin.x + start, y: line.origin.y - descentInLine, width: end - start, height: lineHeight).integral
        }
    }

    private static func horizontalPadding(_ fontSize: CGFloat) -> CGFloat {
        fontSize * 0.6
    }

    private static func width(of line: CTLine) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }

    /// Where line two starts, in UTF-16 units, for the most even lines, or `nil` when the text fits on one or has
    /// nowhere to break. The widths are read off the text laid out as one line.
    private static func split(of text: String, wordRanges: [Range<Int>], fontSize: CGFloat, width available: CGFloat) -> Int? {
        let whole = line(text, fontSize: fontSize)
        let total = width(of: whole)
        guard total > available else { return nil }
        let wider = { (offset: Int) in
            let first = CTLineGetOffsetForStringIndex(whole, offset, nil)
            return max(first, total - first)
        }
        return breaks(in: text, wordRanges: wordRanges).filter { $0 > 0 && $0 < text.utf16.count }.min { wider($0) < wider($1) }
    }

    /// The UI font captions are in.
    private static func font(size: CGFloat) -> CTFont {
        CTFontCreateUIFontForLanguage(.emphasizedSystem, size, nil) ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    }

    private static func line(_ text: String, fontSize: CGFloat) -> CTLine {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font(size: fontSize),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor.white
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }

    /// Each word's place in `text` in UTF-16 units, the units CoreText counts in, up to the first it can't find.
    private static func ranges(of words: [String], in text: String) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var cursor = text.startIndex
        for word in words {
            guard let found = text.range(of: word, range: cursor..<text.endIndex) else { break }
            let start = text.utf16.distance(from: text.startIndex, to: found.lowerBound)
            ranges.append(start..<start + word.utf16.count)
            cursor = found.upperBound
        }
        return ranges
    }

    /// Where a line can break, in UTF-16 units: where a word starts, or after a space.
    private static func breaks(in text: String, wordRanges: [Range<Int>]) -> [Int] {
        var breaks = Set(wordRanges.map(\.lowerBound))
        var offset = 0
        var previousIsSpace = false
        for character in text {
            if previousIsSpace, !character.isWhitespace {
                breaks.insert(offset)
            }
            previousIsSpace = character.isWhitespace
            offset += character.utf16.count
        }
        return breaks.sorted()
    }

    /// Part of `text`, in UTF-16 units, without the spaces at its end. `range` falls between characters, since it
    /// starts at a break.
    private static func substring(of text: String, _ range: Range<Int>) -> String {
        let utf16 = text.utf16
        let start = utf16.index(utf16.startIndex, offsetBy: range.lowerBound)
        let end = utf16.index(utf16.startIndex, offsetBy: range.upperBound)
        var part = Substring(text[start..<end])
        while part.last?.isWhitespace == true {
            part.removeLast()
        }
        return String(part)
    }
}
