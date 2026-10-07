//
//  GlassTests.swift
//  RecoTests
//

import CoreImage
import Foundation
import simd
import Testing
@testable import Reco

/// Lifted UI on glass (spec 0012, the film's port, phase 2): the panel's projection, its shape in the
/// plan, and what it draws.
struct GlassTests {

    @Test(arguments: [
        // A rectangle scaled and moved, and a plane tilted away
        [CGPoint(x: 100, y: 50), CGPoint(x: 1540, y: 50), CGPoint(x: 1540, y: 170), CGPoint(x: 100, y: 170)],
        [CGPoint(x: 120, y: 60), CGPoint(x: 1500, y: 90), CGPoint(x: 1460, y: 200), CGPoint(x: 140, y: 180)]
    ])
    func projectsAPanelOntoItsCorners(corners: [CGPoint]) throws {
        let size = CGSize(width: 576, height: 48)
        let projection = try #require(GlassRenderer.projection(from: size, to: corners))

        for (point, corner) in zip([CGPoint.zero, CGPoint(x: 576, y: 0), CGPoint(x: 576, y: 48), CGPoint(x: 0, y: 48)], corners) {
            let mapped = projection * SIMD3<Double>(point.x, point.y, 1)
            #expect(abs(mapped.x / mapped.z - corner.x) < 1e-6 && abs(mapped.y / mapped.z - corner.y) < 1e-6)
        }
    }

    /// A glass asset's layer sits on a panel its corners and rim scaled from CSS to canvas pixels; the
    /// same asset without glass has none. Its image is whole pixels, as `CIPerspectiveTransform` takes.
    @Test func givesGlassLayersTheirPanel() async throws {
        let (url, document) = try MotionTestBundle.makeGlass()
        defer { try? FileManager.default.removeItem(at: url) }
        var plain = document
        plain.assets[0].glass = nil

        let layer = await MotionPlan.build(document, bundle: url, shorterSide: 270).scenes[0].layers[0]

        #expect(layer.glass == GlassRenderer.Shape(radius: 8, rim: GlassRenderer.rimWidth))
        let extent = try #require(layer.image?.extent)
        #expect(extent.width == extent.width.rounded() && extent.height == extent.height.rounded())
        #expect(await MotionPlan.build(plain, bundle: url, shorterSide: 270).scenes[0].layers[0].glass == nil)
    }

    /// Glass is lifted bare, so it is its own lift.
    @Test func keysGlassLiftsApart() throws {
        var asset = MotionAsset(id: "bar", url: try #require(URL(string: "https://example.com")), selector: "#search")
        let bundle = URL(filePath: "/bundle.motion")
        let plain = UILiftCache.url(of: asset, scale: 4, in: bundle)
        asset.glass = true

        #expect(UILiftCache.url(of: asset, scale: 4, in: bundle) != plain)
    }

    /// Drawn at 1080p: a rim of light along the panel's top edge, brighter than the body inside it; the
    /// bar's text inside; and a shadow on the ground below it, darker than without glass.
    @Test func drawsUIOnGlass() async throws {
        let (url, document) = try MotionTestBundle.makeGlass()
        let (plainURL, plainDocument) = try MotionTestBundle.makeGlass(false)
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: plainURL)
        }
        let glass = try Self.rows(MotionFrameRenderer.image(at: 1, plan: await MotionPlan.build(document, bundle: url, shorterSide: 1080)))
        let plain = try Self.rows(MotionFrameRenderer.image(at: 1, plan: await MotionPlan.build(plainDocument, bundle: plainURL, shorterSide: 1080)))
        // The bar spans x 240–1680 and y 480–600 at 2.5×; its text runs from x 360 at y 525–555
        let column = 1500

        #expect((478...484).map { glass[$0][column] }.max() ?? 0 >= glass[495][column] + 20)
        #expect(glass[540][700] > glass[540][column] + 60)
        let below = { (rows: [[Int]]) in (610...640).flatMap { rows[$0][300...1600] }.reduce(0, +) }
        #expect(below(glass) < below(plain))
    }

    /// The image's green channel as rows of whole levels, top first.
    private static func rows(_ image: CIImage) throws -> [[Int]] {
        let width = 1920, height = 1080
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        CIContext(options: [.workingColorSpace: NSNull()])
            .render(image, toBitmap: &bytes, rowBytes: width * 4, bounds: CGRect(x: 0, y: 0, width: width, height: height), format: .RGBA8, colorSpace: nil)
        return (0..<height).map { row in (0..<width).map { Int(bytes[(row * width + $0) * 4 + 1]) } }
    }
}
