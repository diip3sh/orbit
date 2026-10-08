//
//  SensitiveText.swift
//  Reco
//

import Foundation

/// What in a line of recognized text looks private (spec 0004, N9): email addresses, phone numbers, card numbers and
/// API keys. Pure, so the editor and the screenshot card share it.
nonisolated enum SensitiveText {

    /// The ranges of `text` to hide, in order; overlapping matches are kept, since each is masked anyway.
    static func ranges(in text: String) -> [Range<String.Index>] {
        let whole = NSRange(text.startIndex..., in: text)
        var ranges: [Range<String.Index>] = []
        // Emails come back as mailto: links; other links (example.com) aren't private
        detector?.enumerateMatches(in: text, range: whole) { match, _, _ in
            guard let match, match.resultType == .phoneNumber || match.url?.scheme == "mailto" else { return }
            Range(match.range, in: text).map { ranges.append($0) }
        }
        for pattern in [cardNumber, apiKey] {
            for match in pattern?.matches(in: text, range: whole) ?? [] {
                guard let range = Range(match.range, in: text), pattern != cardNumber || isCardNumber(String(text[range])) else { continue }
                ranges.append(range)
            }
        }
        return ranges.sorted { $0.lowerBound < $1.lowerBound }
    }

    /// Whether `candidate`'s digits are 13 to 19 long and pass the Luhn check, as every card number does; neither
    /// `NSDataDetector` nor `DataDetection` finds cards.
    static func isCardNumber(_ candidate: String) -> Bool {
        let digits = candidate.compactMap(\.wholeNumberValue)
        guard (13...19).contains(digits.count) else { return false }
        let sum = digits.reversed().enumerated().reduce(0) { sum, element in
            let doubled = element.element * 2
            return sum + (element.offset.isMultiple(of: 2) ? element.element : (doubled > 9 ? doubled - 9 : doubled))
        }
        return sum.isMultiple(of: 10)
    }

    private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue | NSTextCheckingResult.CheckingType.phoneNumber.rawValue
    )

    /// 13 to 19 digits, in groups split by single spaces or dashes. `NSRegularExpression`, as Swift's `Regex` has no
    /// lookbehind and isn't `Sendable`.
    private static let cardNumber = try? NSRegularExpression(pattern: #"(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)"#)

    /// Keys with a known prefix: OpenAI and Anthropic (`sk-`), Stripe, GitHub, AWS access keys and Slack tokens.
    private static let apiKey = try? NSRegularExpression(
        pattern: #"\b(?:sk-[A-Za-z0-9_-]{20,}|[sr]k_(?:live|test)_[A-Za-z0-9]{16,}|gh[pousr]_[A-Za-z0-9]{20,}"#
            + #"|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[abprs]-[A-Za-z0-9-]{10,})"#
    )
}
