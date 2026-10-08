//
//  SensitiveTextTests.swift
//  RecoTests
//

import AppKit
import CoreImage
import Testing
@testable import Reco

struct SensitiveTextTests {

    private func found(_ text: String) -> [String] {
        SensitiveText.ranges(in: text).map { String(text[$0]) }
    }

    @Test func findsEmailsAndPhoneNumbersButNotLinks() {
        #expect(found("Write to jane.doe@example.com or see example.com") == ["jane.doe@example.com"])
        #expect(found("Call +1 (415) 555-0132 today") == ["+1 (415) 555-0132"])
    }

    @Test func findsOnlyCardNumbersThatPassLuhn() {
        #expect(found("Card 4242 4242 4242 4242 exp 12/30") == ["4242 4242 4242 4242"])
        #expect(found("Card 4242-4242-4242-4241").isEmpty)
        #expect(SensitiveText.isCardNumber("378282246310005"))
        #expect(!SensitiveText.isCardNumber("4242"))
    }

    @Test func findsKeysByTheirPrefix() {
        // Placeholders shaped like keys, nothing real
        let openAI = "sk-proj-" + String(repeating: "x", count: 24)
        let gitHub = "ghp_" + String(repeating: "x", count: 36)
        #expect(found("OPENAI_API_KEY=\(openAI)") == [openAI])
        #expect(found("aws AKIAIOSFODNN7EXAMPLE ok") == ["AKIAIOSFODNN7EXAMPLE"])
        #expect(found("token \(gitHub)") == [gitHub])
        #expect(found("Version 2026.10.08, build 1234").isEmpty)
    }

    @Test func padsVisionsBoxesAndFlipsThemToTheTopLeft() {
        // 20% across, 10% up from the bottom, 2% tall
        let box = SensitiveTextFinder.box(fromVision: CGRect(x: 0.2, y: 0.1, width: 0.3, height: 0.02), minimumSize: 0.01)

        #expect(abs(box.minX - 0.195) < 1e-9)
        #expect(abs(box.minY - 0.875) < 1e-9)
        #expect(abs(box.height - 0.03) < 1e-9)
    }

    @Test func growsTinyBoxesToTheMinimumInsideTheImage() {
        let box = SensitiveTextFinder.box(fromVision: CGRect(x: 0.99, y: 0, width: 0.005, height: 0.004), minimumSize: 0.02)

        #expect(abs(box.width - 0.02) < 1e-9 && abs(box.height - 0.02) < 1e-9)
        #expect(box.maxX <= 1 && box.maxY <= 1)
    }

    @Test func findsAnEmailInAPicture() async throws {
        let image = try #require(Self.picture(of: "Signed in as jane.doe@example.com", size: CGSize(width: 1600, height: 400)))

        let boxes = try await SensitiveTextFinder.boxes(in: image, minimumSize: 0.02)

        // The email follows "Signed in as " (about 300 px) and is about 500 px long; the line is near the top
        let box = try #require(boxes.first)
        #expect(boxes.count == 1)
        #expect((0.12...0.3).contains(box.minX))
        #expect((0.4...0.7).contains(box.maxX))
        #expect(box.minY < 0.4)
    }

    @Test func aScreenshotsEmailIsPixelatedAndTheRestLeftAlone() async throws {
        let image = try #require(Self.picture(of: "Signed in as jane.doe@example.com", size: CGSize(width: 1600, height: 400)))
        let screenshot = Screenshot(image: image, scale: 2, date: .now, hdrImage: image)

        let (hidden, count) = try await ScreenshotRedactor.hidingSensitiveText(in: screenshot)

        #expect(count == 1)
        #expect(hidden.hdrImage == nil)
        #expect(hidden.image.width == 1600 && hidden.image.height == 400)
        let before = CIImage(cgImage: image)
        let after = CIImage(cgImage: hidden.image)
        // Bottom-right, far from the line of text, is white in both; the email's glyphs are gone into cells
        #expect(after.pixel(at: CGPoint(x: 1500, y: 50)) == before.pixel(at: CGPoint(x: 1500, y: 50)))
        // Across the email (about 240…835 px), through the glyphs: cells of 8 px (2% of 400) replace the strokes
        let row = CGFloat(400 - 120 + 20)
        let changed = (300..<800).count { before.pixel(at: CGPoint(x: CGFloat($0), y: row)) != after.pixel(at: CGPoint(x: CGFloat($0), y: row)) }
        #expect(changed > 100)
        // "Signed in as" is left as it was
        let kept = (60..<200).count { before.pixel(at: CGPoint(x: CGFloat($0), y: row)) != after.pixel(at: CGPoint(x: CGFloat($0), y: row)) }
        #expect(kept == 0)
    }

    /// Black text, 48 pt, on white, from the top-left corner.
    private static func picture(of text: String, size: CGSize) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(.white)
        context.fill(CGRect(origin: .zero, size: size))
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 48), .foregroundColor: NSColor.black])
            .draw(at: CGPoint(x: 40, y: size.height - 120))
        NSGraphicsContext.current = nil
        return context.makeImage()
    }
}
