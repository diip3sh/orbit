//
//  MotionPlanTests.swift
//  RecoTests
//

import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import Reco

struct MotionPlanTests {

    private let bundle = URL.temporaryDirectory

    private func document(_ layers: [MotionLayer], duration: Double = 1) -> MotionDocument {
        MotionDocument(scenes: [MotionScene(id: "scene", duration: duration, layers: layers)])
    }

    private func shape(_ id: String, at position: SIMD3<Double>, opacity: Double = 1) -> MotionLayer {
        var layer = MotionLayer(
            id: id, content: .shape(ShapeContent(size: CGSize(width: 100, height: 100), color: RGBAColor(red: 1, green: 1, blue: 1, alpha: 1))),
            transform: Transform3D(position: position)
        )
        layer.opacity = opacity
        return layer
    }

    @Test func aUILayerWithoutALiftAsksForOneAndIsntDrawn() async throws {
        let asset = MotionAsset(id: "card", url: try #require(URL(string: "https://example.com")), selector: ".card")
        var document = document([MotionLayer(id: "ui", content: .lifted(UIContent(asset: "card")), transform: Transform3D(position: [960, 540, 0]))])
        document.assets = [asset]
        let plan = await MotionPlan.build(document, bundle: bundle)

        #expect(plan.liftsNeeded == ["card": 2])
        #expect(plan.placements(of: plan.scenes[0], at: 0).isEmpty)
    }

    @Test func aLiveLayerWithoutATakeAsksForOne() async throws {
        let step = RecordPageRequest.Step(action: "click", selector: "#buy")
        let asset = MotionAsset(id: "form", url: try #require(URL(string: "https://example.com")), selector: ".form", steps: [step])
        var document = document([MotionLayer(id: "ui", content: .lifted(UIContent(asset: "form")), transform: Transform3D(position: [960, 540, 0]))])
        document.assets = [asset]
        let plan = await MotionPlan.build(document, bundle: bundle)

        // Measured first: only then can the plan say how large the take is shown
        #expect(plan.bakesNeeded == ["form": 0])
        #expect(plan.liftsNeeded.isEmpty)
        #expect(plan.liveLayers.isEmpty)
    }

    @Test func aUILayerAsksForASharperLiftWhenShownLarger() async throws {
        let bundle = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).motion")
        defer { try? FileManager.default.removeItem(at: bundle) }
        let asset = MotionAsset(id: "card", url: try #require(URL(string: "https://example.com")), selector: ".card")
        try FileManager.default.createDirectory(at: bundle.appending(path: "assets/lifts"), withIntermediateDirectories: true)
        // A 400×200 CSS px element lifted at 1×
        try await ScreenshotService.writePNG(try Self.opaqueImage(width: 400, height: 200), to: UILiftCache.url(of: asset, scale: 1, in: bundle))
        var document = document([MotionLayer(
            id: "ui", content: .lifted(UIContent(asset: "card", width: 800)), transform: Transform3D(position: [960, 540, 0])
        )])
        document.assets = [asset]

        let plan = await MotionPlan.build(document, bundle: bundle)
        #expect(plan.scenes[0].layers[0].size == CGSize(width: 800, height: 400))
        #expect(plan.liftsNeeded == ["card": 2])

        try await ScreenshotService.writePNG(try Self.opaqueImage(width: 800, height: 400), to: UILiftCache.url(of: asset, scale: 2, in: bundle))
        let sharp = await MotionPlan.build(document, bundle: bundle)
        #expect(sharp.liftsNeeded.isEmpty)
        #expect(sharp.scenes[0].layers[0].image?.extent == CGRect(x: 0, y: 0, width: 800, height: 400))
    }

    private static func opaqueImage(width: Int, height: Int) throws -> CGImage {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }

    @Test func findsTheSceneOnScreen() async throws {
        let plan = await MotionPlan.build(try JSONDecoder().decode(MotionDocument.self, from: Fixture.data("motion-demo")), bundle: bundle)

        #expect(plan.duration == 5)
        #expect(plan.frameCount == 300)
        #expect(plan.scene(at: 1.9).scene.start == 0)
        #expect(plan.scene(at: 2).scene.start == 2)
        #expect(plan.scene(at: 2).time == 0)
        #expect(plan.scene(at: 9).time == 7)
    }

    @Test func outputIsScaledToItsShorterSideAndEven() async {
        var document = document([])
        document.canvas.size = CGSize(width: 1920, height: 1080)
        let plan = await MotionPlan.build(document, bundle: bundle, shorterSide: 271)

        #expect(plan.outputSize == CGSize(width: 482, height: 272))
    }

    @Test func groupsCarryTheirTransformAndOpacity() async throws {
        var group = MotionLayer(id: "group", content: .group([shape("child", at: [100, 0, 0])]), transform: Transform3D(position: [960, 540, 0]))
        group.opacity = 0.5
        let plan = await MotionPlan.build(document([group]), bundle: bundle)

        let placements = plan.placements(of: plan.scenes[0], at: 0)
        let placement = try #require(placements.first)
        #expect(placements.count == 1)
        #expect(placement.layer == 1)
        #expect(placement.corners[0] == CGPoint(x: 1010, y: 490))
        #expect(placement.opacity == 0.5)
    }

    @Test func drawsFarthestFirstAndLeavesOutTransparentLayers() async {
        let plan = await MotionPlan.build(document([
            shape("near", at: [960, 540, -100]), shape("far", at: [960, 540, 100]), shape("hidden", at: [960, 540, 0], opacity: 0)
        ]), bundle: bundle)

        #expect(plan.placements(of: plan.scenes[0], at: 0).map(\.layer) == [1, 0])
    }

    @Test func drawsImagesAtTheLargestScaleTheyAreShown() async {
        var grows = MotionLayer(id: "grows", content: .text(TextContent(text: "Big")), transform: Transform3D(position: [960, 540, 0]))
        grows.keyframes[.scale] = [Keyframe(time: 0, value: 1), Keyframe(time: 1, value: 3)]
        var macro = grows
        macro.id = "macro"
        macro.keyframes[.scale] = [Keyframe(time: 0, value: 1), Keyframe(time: 1, value: 10)]
        var page = MotionLayer(id: "page", content: .shape(ShapeContent(size: CGSize(width: 6000, height: 3000), color: RGBAColor(red: 1, green: 1, blue: 1, alpha: 1))))
        page.keyframes[.scale] = macro.keyframes[.scale] ?? []

        let plan = await MotionPlan.build(document([grows, macro, page]), bundle: bundle, shorterSide: 540)

        #expect(abs(plan.scenes[0].layers[0].rasterScale - 1.5) < 1e-9)
        // Small, so sharp at 10×, times the output's half scale
        #expect(abs(plan.scenes[0].layers[1].rasterScale - 5) < 1e-9)
        // Large: capped at 4×, as 8,192 px would be softer still
        #expect(plan.scenes[0].layers[2].rasterScale == 2)
    }

    /// A small still is lifted past 8× while its lift fits 8,192 px; a large one stops at 8×.
    @Test func liftsSmallElementsSharperForMacro() {
        let bar = UILiftCache.Lift(url: URL(filePath: "/bar.png"), scale: 2, size: CGSize(width: 576, height: 48))
        let page = UILiftCache.Lift(url: URL(filePath: "/page.png"), scale: 2, size: CGSize(width: 1440, height: 900))

        #expect(MotionPlan.liftScale(for: bar, width: 576, rasterScale: 14) == 14)
        #expect(MotionPlan.liftScale(for: bar, width: 576, rasterScale: 40) == 14)
        #expect(MotionPlan.liftScale(for: page, width: 1440, rasterScale: 14) == 8)
    }
}
