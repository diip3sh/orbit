//
//  CameraCraftTests.swift
//  RecoTests
//

import CoreImage
import Foundation
import Testing
@testable import Reco

/// The After Effects bar (spec 0020): a camera at an angle and arcing, a swing, a flow carrying a layer into the next scene,
/// the pool of light, and the check for a product small in its frame.
struct CameraCraftTests {

    /// The scene turns about where the camera looks: that point stays, the top leaning away shows smaller than the bottom
    /// coming nearer, farther and nearer than the middle.
    @Test func anAngleTurnsTheSceneAboutWhereTheCameraLooks() throws {
        let canvas = CGSize(width: 1920, height: 1080)
        let camera = CameraProjection(lookAt: CGPoint(x: 960, y: 540), dolly: 0, canvas: canvas, angle: [30, 0, 0])
        let middle = try #require(camera.project([960, 540, 0]))
        let (top, bottom) = (try #require(camera.project([960, 240, 0])), try #require(camera.project([960, 840, 0])))

        #expect(abs(middle.point.x - 960) < 1e-9 && abs(middle.point.y - 540) < 1e-9)
        #expect(top.point.y > 240 && top.depth > middle.depth && bottom.depth < middle.depth)
        #expect(bottom.point.y - 540 > 540 - top.point.y)
        #expect(camera.order(of: [960, 240, 0]) == camera.order(of: [960, 840, 0]))
    }

    /// A card lying back keeps what's on it in front of it, whichever side is farther.
    @Test func aCardKeepsWhatsOnItInFront() async throws {
        let json = #"""
            {"version": 1, "scenes": [{"id": "one", "duration": 2, "camera": {"angle": [20, -25, 0]}, "layers": [
              {"id": "card", "transform": {"position": [960, 540, 0]}, "content": {"group": [
                {"id": "face", "content": {"shape": {"size": [1200, 500], "color": "#202020"}}},
                {"id": "word", "transform": {"position": [-500, 0, 0]}, "content": {"text": {"text": "Left", "size": 60}}}]}}]}]}
            """#
        let plan = await MotionPlan.build(try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8)), bundle: URL.temporaryDirectory)
        let scene = plan.scenes[0]
        let order = plan.placements(of: scene, at: 1).map { scene.layers[$0.layer].id }

        #expect(order == ["face", "word"])
        #expect(scene.cameraValue(.aperture, at: 1) == MotionCamera.angledAperture)
    }

    /// An arc turns the scene at its steady pace, the other way from where the camera goes.
    @Test func anArcTurnsTheCamera() {
        var arc = MotionMove(.arc)
        arc.direction = .right
        arc.duration = 2
        let tracks = MoveExpansion.effect(of: arc, in: MoveContext(sceneDuration: 2, canvas: CGSize(width: 1920, height: 1080))).tracks

        #expect(tracks[.rotationY]?.first?.value(at: 2) == -MoveExpansion.arcSpeed * 2)
        #expect(tracks[.rotationX]?.first?.value(at: 2) == 0)
    }

    /// A camera that stops early creeps on to its scene's end; one held stays still.
    @Test func aCameraThatStopsEarlyCreepsOn() async throws {
        let json = #"""
            {"version": 1, "scenes": [{"id": "one", "duration": 3, "camera": {"moves": [{"move": "push"}]}},
                                      {"id": "two", "duration": 3, "camera": {"moves": [{"move": "hold"}]}}, {"id": "end", "duration": 2}]}
            """#
        let plan = await MotionPlan.build(try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8)), bundle: URL.temporaryDirectory)
        let (pushed, held) = (plan.scenes[0], plan.scenes[1])

        #expect(pushed.cameraValue(.scale, at: 2.5) > pushed.cameraValue(.scale, at: 1.3) + 0.01)
        #expect(held.cameraValue(.scale, at: 2.5) == held.cameraValue(.scale, at: 1.3))
    }

    /// A swing turns the scene before away and the next in from the other side, two swings going different ways.
    @Test func aSwingTurnsOutAndIn() {
        let swing = { (variant: Int) in
            SeamExpansion.effect(
                of: .swing, outgoingDuration: 2, canvas: CGSize(width: 1920, height: 1080), hasText: false, velocity: SeamExpansion.Velocity(), variant: variant
            )
        }
        let (even, odd) = (swing(2), swing(3))

        #expect(even.transition == nil)
        let turn = { (effect: SeamExpansion.Effect, outgoing: Bool) in
            (outgoing ? effect.outgoing : effect.incoming)[.rotationY]?.first?.value(at: outgoing ? 2 : 0) ?? 0
        }
        #expect(abs(turn(even, true) - SeamExpansion.swingOut.degrees) < 1e-6)
        #expect(abs(turn(even, false) + SeamExpansion.swingIn.degrees) < 1e-6)
        #expect(abs(turn(odd, true) + SeamExpansion.swingOut.degrees) < 1e-6)
    }

    /// A flow: the scene before's other layers leave from just before the cut, the next's arrive, and the layer both have
    /// travels between its places, its colour changing on the way.
    @Test func aFlowCarriesALayerIntoTheNextScene() async throws {
        let json = #"""
            {"version": 1, "canvas": {"background": "#000000"}, "scenes": [
              {"id": "one", "duration": 2, "camera": {"moves": [{"move": "hold"}]}, "layers": [
                {"id": "pill", "transform": {"position": [400, 300, 0]}, "content": {"shape": {"size": [200, 80], "cornerRadius": 40, "color": "#ff0000"}}},
                {"id": "note", "transform": {"position": [1500, 800, 0]}, "content": {"shape": {"size": [100, 100], "color": "#ffffff"}}}]},
              {"id": "two", "duration": 2, "seam": "flow", "camera": {"moves": [{"move": "hold"}]}, "layers": [
                {"id": "pill", "transform": {"position": [1200, 700, 0]}, "content": {"shape": {"size": [800, 500], "cornerRadius": 24, "color": "#0000ff"}}},
                {"id": "label", "transform": {"position": [300, 900, 0]}, "content": {"shape": {"size": [100, 100], "color": "#00ff00"}}}]}]}
            """#
        let plan = await MotionPlan.build(try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8)), bundle: URL.temporaryDirectory, shorterSide: 540)
        let (one, two) = (plan.scenes[0], plan.scenes[1])
        let note = try #require(one.layers.first { $0.id == "note" })
        let label = try #require(two.layers.first { $0.id == "label" })

        #expect(MotionPlan.carried(from: one, to: two) == ["pill"])
        #expect(two.transition?.seam == .flow && one.overlap == SeamExpansion.flowDuration)
        #expect(note.value(.opacity, at: 2 - MotionPlan.flowLeave.lead) == 1 && note.value(.opacity, at: 2.3) < 0.05)
        #expect(label.value(.opacity, at: 0) == 0 && label.value(.opacity, at: 0.8) == 1)

        // Half way, the pill is between its places and between its colours
        let time = two.start + MotionPlan.flowCarry.duration / 2
        let frame = MotionFrameRenderer.image(at: time, plan: plan)
        let middle = CGPoint(x: (400 + 1200) / 2 * plan.outputScale, y: (1080 - (300 + 700) / 2) * plan.outputScale)
        let color = try Self.color(of: frame, at: middle)
        #expect(color[0] > 60 && color[2] > 60 && color[1] < 40, "\(color)")
    }

    /// The pool lights its middle in the brand's hue over the background, which its corners keep.
    @Test func aPoolLightsItsMiddle() throws {
        let background = try #require(RGBAColor(hex: "#08090a"))
        let palette = FieldPalette(.pool, style: StyleTokens(accent: RGBAColor(hex: "#2680d9")), background: background)
        let size = CGSize(width: 320, height: 180)
        let image = FieldRenderer.image(.pool, palette: palette, at: 0, size: size)
        let (middle, corner) = (try Self.color(of: image, at: CGPoint(x: 160, y: 104)), try Self.color(of: image, at: CGPoint(x: 1, y: 1)))

        #expect(middle[2] > corner[2] + 25 && middle[2] > middle[0])
        #expect(corner[2] < 20)
        #expect(MotionField.pool.family == .plain)
    }

    /// A line alone in the middle of the frame is small.
    @Test func smallContentIsNamed() async throws {
        let scene = { (id: String) in
            #"{"id": "\#(id)", "duration": 2, "camera": {"moves": [{"move": "hold"}]}, "layers": [{"id": "w\#(id)", "#
                + #""transform": {"position": [960, 540, 0]}, "content": {"text": {"text": "A small line", "size": 48}}}]}"#
        }
        let json = #"{"version": 1, "scenes": ["# + ["a", "b", "c", "d"].map(scene).joined(separator: ",") + "]}"
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8))
        let plan = await MotionPlan.build(document, bundle: URL.temporaryDirectory, shorterSide: 135)

        #expect(DesignCheck.smallContent(in: plan, scenes: document.scenes.map(\.id)).count == 3)
    }

    // MARK: - Helpers

    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    /// The RGB bytes of the pixel at `point` (Core Image's coordinates, from the bottom left).
    private static func color(of image: CIImage, at point: CGPoint) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        context.render(image, toBitmap: &bytes, rowBytes: 4, bounds: CGRect(origin: point, size: CGSize(width: 1, height: 1)), format: .RGBA8, colorSpace: nil)
        return Array(bytes.prefix(3))
    }
}
