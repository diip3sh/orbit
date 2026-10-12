//
//  TextImageTests.swift
//  RecoTests
//

import CoreGraphics
import Testing
@testable import Reco

struct TextImageTests {

    @Test func drawsAtScaleAndFindsEveryWord() throws {
        let text = TextImage(TextContent(text: "Agents for DevOps", size: 100), scale: 2)
        let image = try #require(text.image)

        #expect(image.width == Int((text.size.width * 2).rounded(.up)))
        #expect(text.words.count == 3)
        #expect(text.lines.count == 1)
        // Left to right, apart, inside the layer
        #expect(zip(text.words, text.words.dropFirst()).allSatisfy { $0.maxX <= $1.minX })
        #expect(text.words.allSatisfy { CGRect(origin: .zero, size: text.size).insetBy(dx: -1, dy: -1).contains($0) })
    }

    @Test func wrapsAtItsWidth() {
        let text = TextImage(TextContent(text: "One idea per shot, then a cut", size: 80, width: 500), scale: 1)

        #expect(text.size.width == 500)
        #expect(text.lines.count > 1)
        // Lines run down from the top
        #expect(zip(text.lines, text.lines.dropFirst()).allSatisfy { $0.minY < $1.minY })
    }

    @Test func emptyTextHasNoImage() {
        #expect(TextImage(TextContent(text: ""), scale: 1).image == nil)
    }
}
