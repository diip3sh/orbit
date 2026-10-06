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
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
    }
}
