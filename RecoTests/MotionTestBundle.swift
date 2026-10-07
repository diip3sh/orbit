//
//  MotionTestBundle.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Reco

/// The hand-written demo (`motion-demo.json`: a title, an image on a tilted plane, a push) in a
/// bundle in a temporary folder, with its card drawn.
enum MotionTestBundle {

    static func make() throws -> (url: URL, document: MotionDocument) {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).motion")
        try FileManager.default.createDirectory(at: url.appending(path: "assets"), withIntermediateDirectories: true)
        let data = try Fixture.data("motion-demo")
        try data.write(to: MotionStore.documentURL(in: url))
        try writeCard(to: url.appending(path: "assets/card.png"))
        return (url, try JSONDecoder().decode(MotionDocument.self, from: data))
    }

    /// The grammar's shots (`motion-grammar.json`) in a bundle, its 600×350 CSS pixel card lifted
    /// at `scale` (8× is sharp enough for any plan, so nothing is lifted from the web).
    static func makeGrammar(scale: Int = 2) throws -> (url: URL, document: MotionDocument) {
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).motion")
        let data = try Fixture.data("motion-grammar")
        let document = try JSONDecoder().decode(MotionDocument.self, from: data)
        let lift = UILiftCache.url(of: document.assets[0], scale: scale, in: url)
        try FileManager.default.createDirectory(at: lift.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: MotionStore.documentURL(in: url))
        try writeCard(to: lift, scale: Double(scale) / 2)
        return (url, document)
    }

    /// A search bar on glass over satin, seen at 2.5×: 576×48 CSS pixels lifted bare at 4× (a magnifier
    /// and a line of text, no fill of its own), its corners 8 px round. With `glass` false, the same bar
    /// without it.
    static func makeGlass(_ glass: Bool = true) throws -> (url: URL, document: MotionDocument) {
        let json = #"""
            {"version": 1, "canvas": {"field": "satin"},
             "assets": [{"id": "bar", "url": "https://example.com", "selector": "#search", "glass": \#(glass)}],
             "scenes": [{"id": "macro", "duration": 2, "camera": {"keyframes": {"scale": [{"time": 0, "value": 2.5}]}},
                         "layers": [{"id": "bar", "content": {"ui": {"asset": "bar"}}, "transform": {"position": [960, 540, 0]}}]}]}
            """#
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).motion")
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8))
        let lift = UILiftCache.url(of: document.assets[0], scale: 4, in: url)
        try FileManager.default.createDirectory(at: lift.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(json.utf8).write(to: MotionStore.documentURL(in: url))
        try JSONEncoder().encode(UILiftCache.Shape(radius: 8)).write(to: UILiftCache.shapeURL(of: document.assets[0], in: url))
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: 576 * 4, height: 48 * 4, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.scaleBy(x: 4, y: 4)
        context.setStrokeColor(CGColor(srgbRed: 0.6, green: 0.6, blue: 0.6, alpha: 1))
        context.setLineWidth(2)
        context.strokeEllipse(in: CGRect(x: 18, y: 16, width: 14, height: 14))
        context.setFillColor(CGColor(srgbRed: 0.6, green: 0.6, blue: 0.6, alpha: 1))
        context.fill(CGRect(x: 48, y: 18, width: 200, height: 12))
        try write(try #require(context.makeImage()), to: lift)
        return (url, document)
    }

    /// A search field typed into ("ab", from 0.5 s) on glass over satin, its lifts at 2×: the row
    /// (576×48 CSS pixels) empty and with each letter, the whole field (576×200) once its results
    /// settle, a bar of results under the row, and again with the next result selected (a second bar);
    /// the selection moves down at 2 s and back up at 2.5 and 2.8 s.
    static func makeTyping() throws -> (url: URL, document: MotionDocument) {
        let json = #"""
            {"version": 1, "canvas": {"field": "satin"},
             "assets": [{"id": "search", "url": "https://example.com", "selector": "#search", "glass": true,
                         "typing": {"field": "#q", "text": "ab", "select": 1}}],
             "scenes": [{"id": "typed", "duration": 3,
                         "layers": [{"id": "search", "transform": {"position": [960, 540, 0]},
                                     "content": {"ui": {"asset": "search", "typingStart": 0.5,
                                                        "presses": [{"key": "down", "time": 2}, {"key": "up", "time": 2.5}, {"key": "up", "time": 2.8}]}}}]}]}
            """#
        let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).motion")
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8))
        let asset = document.assets[0]
        try FileManager.default.createDirectory(at: UILiftCache.url(of: asset, scale: 2, in: url).deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(json.utf8).write(to: MotionStore.documentURL(in: url))
        try JSONEncoder().encode(UILiftCache.Shape(radius: 8)).write(to: UILiftCache.shapeURL(of: asset, in: url))
        let typing = UILiftCache.Typing(
            row: CGRect(x: 0, y: 0, width: 576, height: 48), ends: [40, 50, 60], line: 24, fontSize: 16, settled: [2], heights: [200], selections: [97, 137]
        )
        try JSONEncoder().encode(typing).write(to: UILiftCache.typingURL(of: asset, in: url))
        try writeField(to: UILiftCache.url(of: asset, scale: 2, in: url), height: 48, typed: 0)
        try writeField(to: UILiftCache.typedURL(of: asset, length: 1, scale: 2, in: url), height: 48, typed: 1)
        try writeField(to: UILiftCache.typedURL(of: asset, length: 2, scale: 2, in: url), height: 48, typed: 2)
        try writeField(to: UILiftCache.settledURL(of: asset, length: 2, scale: 2, in: url), height: 200, typed: 2)
        try writeField(to: UILiftCache.selectedURL(of: asset, presses: 1, scale: 2, in: url), height: 200, typed: 2, selected: true)
        return (url, document)
    }

    /// A field 576 CSS pixels wide and `height` tall at 2×, no fill of its own: a magnifier, a bar per
    /// letter typed, and under the row a bar of results if it's taller than the row, and a second if
    /// the next result is `selected`.
    private static func writeField(to url: URL, height: Int, typed: Int, selected: Bool = false) throws {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: 576 * 2, height: height * 2, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        // Top-left origin, as CSS
        context.translateBy(x: 0, y: CGFloat(height * 2))
        context.scaleBy(x: 2, y: -2)
        context.setStrokeColor(CGColor(srgbRed: 0.6, green: 0.6, blue: 0.6, alpha: 1))
        context.setLineWidth(2)
        context.strokeEllipse(in: CGRect(x: 16, y: 17, width: 14, height: 14))
        context.setFillColor(CGColor(srgbRed: 0.9, green: 0.9, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 40, y: 18, width: typed * 10, height: 12))
        if height > 48 {
            context.fill(CGRect(x: 40, y: 90, width: 300, height: 14))
        }
        if selected {
            context.fill(CGRect(x: 40, y: 130, width: 300, height: 14))
        }
        try write(try #require(context.makeImage()), to: url)
    }

    private static func write(_ image: CGImage, to url: URL) throws {
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }

    /// A 1200×700 dark card with a light bar per row, so a tilt and a blur show, `scale` times as large.
    private static func writeCard(to url: URL, scale: Double = 1) throws {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: Int(1200 * scale), height: Int(700 * scale), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.scaleBy(x: scale, y: scale)
        context.setFillColor(CGColor(srgbRed: 0.09, green: 0.1, blue: 0.11, alpha: 1))
        context.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: 1200, height: 700), cornerWidth: 24, cornerHeight: 24, transform: nil))
        context.fillPath()
        context.setFillColor(CGColor(srgbRed: 0.8, green: 0.82, blue: 0.85, alpha: 1))
        for row in 0..<8 {
            context.fill(CGRect(x: 60, y: 60 + row * 76, width: 300 + (row * 97) % 600, height: 24))
        }
        try write(try #require(context.makeImage()), to: url)
    }
}
