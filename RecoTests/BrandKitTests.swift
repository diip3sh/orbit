//
//  BrandKitTests.swift
//  RecoTests
//

import AppKit
import Foundation
import Testing
@testable import Reco

/// A launch film in the brand's own taste (spec 0019): what inspect_page reads of it (its faces' files, palette, gradients,
/// radii, how its heading is set) and its type drawn in its own face.
@MainActor
struct BrandKitTests {

    /// The heading's face resolved to its Latin file at the closest weight, next/font's mangled family named as people name it;
    /// the button's radius, a gradient's stops, the heading's tracking.
    @Test func inspectingReadsTheBrandKit() async throws {
        let page = """
            <!doctype html><html><head><style>
            @font-face { font-family: "__Brand_ab12cd"; src: url(https://fonts.example.com/brand-cyrillic.woff2) format("woff2");
              font-weight: 100 900; unicode-range: U+0400-045F; }
            @font-face { font-family: "__Brand_ab12cd"; src: url(https://fonts.example.com/brand.woff2) format("woff2"); font-weight: 100 900; unicode-range: U+0000-00FF, U+0131; }
            @font-face { font-family: "__Brand_ab12cd"; src: url(https://fonts.example.com/brand-italic.woff2) format("woff2"); font-style: italic; }
            h1 { font-family: "__Brand_ab12cd", sans-serif; font-weight: 700; letter-spacing: -0.02em; font-size: 64px }
            </style></head><body style="margin: 0; background: rgb(250, 250, 250)">
            <h1>Launch videos</h1>
            <div style="height: 200px; background: linear-gradient(90deg, rgb(255, 90, 31), rgb(122, 44, 255))"></div>
            <a href="#" style="display: inline-block; width: 200px; height: 50px; border-radius: 999px; background: rgb(255, 90, 31)">Start</a>
            </body></html>
            """
        var script = WebScript()
        script.url = URL(string: "data:text/html;charset=utf-8," + (page.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""))
        script.viewport = CGSize(width: 640, height: 400)
        script.scale = 1
        script.duration = 0.5

        let brand = try #require(try await WebPageRenderer(script: script).inspect(selectors: []).brand)

        #expect(brand.font == "Brand")
        #expect(brand.fonts == [PageInspection.Font(role: "heading", family: "Brand", weight: 700, url: "https://fonts.example.com/brand.woff2")])
        #expect(brand.heading?.weight == 700 && abs((brand.heading?.tracking ?? 0) + 0.02) < 0.001 && brand.heading?.uppercase == false)
        #expect(brand.gradients?.first == ["#ff5a1f", "#7a2cff"])
        #expect(brand.radius?.button == 999)
        #expect(brand.palette?.first == "#fafafa")
    }

    /// A document's font is fetched into its bundle, and text set in it is drawn in it: wider than SF Pro in Courier New.
    @Test func textIsSetInTheBrandsFace() async throws {
        let bundle = URL.temporaryDirectory.appending(path: "brand-\(UUID().uuidString).motion")
        defer { try? FileManager.default.removeItem(at: bundle) }
        let font = MotionFont(family: "Brand Serif", url: URL(filePath: "/System/Library/Fonts/Supplemental/Courier New.ttf"))
        await FontCapture.fetch([font], into: bundle)
        #expect(FileManager.default.fileExists(atPath: BrandFonts.file(for: font, in: bundle).path(percentEncoded: false)))
        BrandFonts.load([font], bundle: bundle)

        var text = TextContent(text: "Every lead answered")
        let system = TextImage(text, scale: 0).size.width
        text.font = "Brand Serif"
        let courier = NSFont(name: "Courier New", size: text.size) ?? .systemFont(ofSize: text.size)
        let expected = NSAttributedString(string: text.text, attributes: [.font: courier, .kern: TextImage.tracking(of: text)]).size().width
        #expect(abs(TextImage(text, scale: 0).size.width - expected) < 2 && abs(expected - system) > 10)
    }

    /// `style.font` sets every text without its own, but code; the bundle's file isn't needed for that.
    @Test func theStylesFontSetsEveryText() throws {
        let json = #"""
            {"version": 1, "style": {"font": "Brand"}, "fonts": [{"family": "Brand", "url": "https://fonts.example.com/brand.woff2"}],
             "scenes": [{"id": "one", "duration": 2, "layers": [
               {"id": "title", "content": {"text": {"text": "Hello"}}},
               {"id": "code", "content": {"text": {"text": "npm i", "face": "mono"}}},
               {"id": "group", "content": {"group": [{"id": "own", "content": {"text": {"text": "Own", "font": "Other"}}}]}}]}]}
            """#
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8)).brandSet
        let fonts = document.scenes[0].layers.map { layer -> [String?] in
            switch layer.content {
            case .text(let text): [text.font]
            case .group(let children): children.map { if case .text(let text) = $0.content { text.font } else { nil } }
            default: []
            }
        }
        #expect(fonts == [["Brand"], [nil], ["Other"]])
        #expect(document.fonts.first?.family == "Brand")
    }
}
