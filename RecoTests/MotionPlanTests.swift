//
//  MotionPlanTests.swift
//  RecoTests
//

import CoreGraphics
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
        var huge = grows
        huge.id = "huge"
        huge.keyframes[.scale] = [Keyframe(time: 0, value: 1), Keyframe(time: 1, value: 10)]

        let plan = await MotionPlan.build(document([grows, huge]), bundle: bundle, shorterSide: 540)

        #expect(abs(plan.scenes[0].layers[0].rasterScale - 1.5) < 1e-9)
        // Capped at 4×, times the output's half scale
        #expect(plan.scenes[0].layers[1].rasterScale == 2)
    }
}
