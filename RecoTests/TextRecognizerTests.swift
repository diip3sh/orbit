//
//  TextRecognizerTests.swift
//  RecoTests
//
//  Created by Diip3sh on 29.09.26.
//

import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import Reco

struct TextRecognizerTests {

    // MARK: - joined

    @Test func joinsLinesTopToBottom() {
        let text = TextRecognizer.joined([
            (text: "second", boundingBox: CGRect(x: 0.1, y: 0.4, width: 0.5, height: 0.1)),
            (text: "first", boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.5, height: 0.1))
        ])

        #expect(text == "first\nsecond")
    }

    @Test func linesOnOneRowGoLeftToRight() {
        let text = TextRecognizer.joined([
            (text: "right", boundingBox: CGRect(x: 0.6, y: 0.8, width: 0.3, height: 0.1)),
            (text: "left", boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.3, height: 0.1))
        ])

        #expect(text == "left\nright")
    }

    @Test func noLinesGiveNoText() {
        #expect(TextRecognizer.joined([]).isEmpty)
    }

    // MARK: - text(in:)

    @Test func recognizesDrawnLinesTopToBottom() async throws {
        let text = try await TextRecognizer.text(in: Self.image(lines: ["Hello World", "Second line"]))

        #expect(text == "Hello World\nSecond line")
    }

    @Test func anImageWithoutTextGivesNoText() async throws {
        let text = try await TextRecognizer.text(in: .filled(width: 400, height: 200))

        #expect(text.isEmpty)
    }

    /// Black 64 pt Helvetica lines on white, the first at the top
    private static func image(lines: [String]) throws -> CGImage {
        let width = 800
        let lineHeight = 120
        let height = lineHeight * lines.count
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let font = CTFontCreateWithName("Helvetica" as CFString, 64, nil)
        for (index, line) in lines.enumerated() {
            let string = NSAttributedString(string: line, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
            // Core Graphics' origin is bottom-left
            context.textPosition = CGPoint(x: 40, y: height - (index + 1) * lineHeight + 36)
            CTLineDraw(CTLineCreateWithAttributedString(string), context)
        }
        return try #require(context.makeImage())
    }
}
