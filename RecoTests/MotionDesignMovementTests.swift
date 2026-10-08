//
//  MotionDesignMovementTests.swift
//  RecoTests
//

import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import Reco

/// How motion design moves (spec 0014, after a second look at the reference): letters spring past their line, particles
/// stay sharp, the pointer comes up from below the frame, a glyph spins in, a camera pans in and back out, and a scene
/// never holds still for more than a beat and a half.
struct MotionDesignMovementTests {

    private let bundle = URL.temporaryDirectory

    private func document(_ layers: String, duration: Double = 4, camera: String = "[]") throws -> MotionDocument {
        var scene = MotionScene(id: "scene", duration: duration, layers: try JSONDecoder().decode([MotionLayer].self, from: Data(layers.utf8)))
        scene.camera.moves = try JSONDecoder().decode([MotionMove].self, from: Data(camera.utf8))
        var document = MotionDocument(scenes: [scene])
        document.canvas.frameRate = 30
        document.canvas.field = .plain
        document.canvas.background = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
        document.style.accent = RGBAColor(hex: "#1ed760")
        return document
    }

    private func disc(_ moves: String) -> String {
        #"[{"id": "disc", "content": {"shape": {"size": [100, 100], "cornerRadius": 50, "color": "1ed760"}}, "transform": {"position": [960, 540, 0]}, "moves": \#(moves)}]"#
    }

    @Test func aLetterRisesPastItsLineAndSettles() {
        let start = TextReveal.letterPose(0)
        #expect(abs(start.below - TextReveal.letterBelow) < 1e-6 && abs(start.scale - TextReveal.letterFrom) < 1e-6 && start.opacity == 0)
        let peak = TextReveal.letterPose(TextReveal.letterPeak)
        #expect(abs(peak.below - TextReveal.letterAbove) < 1e-6 && abs(peak.scale - TextReveal.letterGrowth) < 1e-6 && peak.opacity == 1)
        // Down from the peak without a second bounce
        let settling = stride(from: TextReveal.letterPeak, through: 1, by: 0.05).map { TextReveal.letterPose($0).scale }
        #expect(zip(settling, settling.dropFirst()).allSatisfy { $0 >= $1 })
        let end = TextReveal.letterPose(1)
        #expect(abs(end.below) < 1e-6 && abs(end.scale - 1) < 1e-6 && end.opacity == 1)
    }

    @Test func lettersAreDrawnAboveTheirLineAtTheirPeak() async throws {
        let text = #"[{"id": "h", "content": {"text": {"text": "HH", "size": 200, "color": "ffffff"}}, "transform": {"position": [960, 540, 0]},"#
            + #" "moves": [{"move": "letters", "start": 0.1}]}]"#
        let plan = await MotionPlan.build(try document(text), bundle: bundle, shorterSide: 270, frameRate: 30)
        let placement = try #require(plan.placements(of: plan.scenes[0], at: 1).first)
        #expect(placement.roomCorners != nil && plan.scenes[0].layers[0].revealRoom.height > 0)
        let top = { (time: Double) in
            try MotionDesignTests.box(of: MotionFrameRenderer.image(at: time, plan: plan), size: plan.outputSize) { $0[0] > 128 }.minY
        }

        // The first letter at its peak reaches higher than the text at rest, outside the layer's own box
        let peak = 0.1 + TextReveal.letterPeak * MoveExpansion.letterDuration
        #expect(try top(peak) < top(1) - 3)
        #expect(try top(peak) < placement.corners[0].y * 0.25)
    }

    @Test func aBurstsParticlesAreDrawnAtTheFramesOwnTime() async throws {
        let plan = await MotionPlan.build(try document(disc(#"[{"move": "burst", "start": 1}]"#)), bundle: bundle)
        let scene = plan.scenes[0]

        #expect(BurstExpansion.isParticles("disc.burst0") && !BurstExpansion.isParticles("disc") && !BurstExpansion.isParticles("x.burst"))
        #expect(scene.layers.filter(\.isSharp).count == BurstExpansion.particles + 1)
        #expect(scene.layers.contains { !$0.isSharp && $0.morph == nil && $0.parent == nil })
        let sharpened = MotionFrameRenderer.sharpened(plan.placements(of: scene, at: 1.11), at: plan.placements(of: scene, at: 1.1), of: scene)
        let atFrame = plan.placements(of: scene, at: 1.1).filter { scene.layers[$0.layer].isSharp }
        #expect(sharpened.filter { scene.layers[$0.layer].isSharp } == atFrame)
    }

    @Test func thePointerComesUpFromBelowTheFrame() {
        let click = MotionPlan.Click(press: 1, leaves: 1.8)
        let corners = [CGPoint(x: 860, y: 500), CGPoint(x: 1060, y: 500), CGPoint(x: 1060, y: 580), CGPoint(x: 860, y: 580)]
        let canvas = CGSize(width: 1920, height: 1080)
        let appears = click.press - MotionPointer.landing - MotionPointer.travel

        let first = MotionPointer.tip(of: click, on: corners, at: appears, canvas: canvas)
        #expect(first?.point.y ?? 0 > canvas.height && first?.opacity == 1)
        #expect(MotionPointer.tip(of: click, on: corners, at: appears - 0.01, canvas: canvas) == nil)
        // Fast, then slowing onto its target
        let halfway = MotionPointer.tip(of: click, on: corners, at: appears + MotionPointer.travel / 2, canvas: canvas)?.point.y ?? 0
        let landed = MotionPointer.tip(of: click, on: corners, at: click.press, canvas: canvas)?.point.y ?? 0
        #expect(halfway - landed < (first?.point.y ?? 0) - halfway)
    }

    @Test func aGlyphSpinsIntoPlace() async throws {
        let plus = #"[{"id": "plus", "content": {"shape": {"kind": "plus", "size": [80, 80], "color": "ffffff"}}, "transform": {"position": [960, 540, 0]},"#
            + #" "moves": [{"move": "pop", "start": 0.2}, {"move": "spin", "start": 0.2}]}]"#
        let layer = await MotionPlan.build(try document(plus), bundle: bundle).scenes[0].layers[0]

        #expect(abs(layer.value(.rotationZ, at: 0.2) + MoveExpansion.spinTurn) < 1e-9)
        #expect(layer.value(.rotationZ, at: 0.45) > 0)
        #expect(abs(layer.value(.rotationZ, at: 0.2 + MoveExpansion.spinDuration)) < 1e-9)
    }

    @Test func aPanBackOutFollowsAPanIn() async throws {
        let camera = #"[{"move": "pan", "start": 0.2, "duration": 0.6, "to": [1430, 540], "intensity": 2},"#
            + #" {"move": "pan", "start": 1.5, "duration": 0.6, "to": [960, 540], "intensity": 1}]"#
        let scene = await MotionPlan.build(try document(disc("[]"), camera: camera), bundle: bundle).scenes[0]
        let (scale, across) = (scene.cameraValue(.scale, at: 0), scene.cameraValue(.positionX, at: 0))

        #expect(abs(scene.cameraValue(.scale, at: 1) / scale - 2) < 1e-6)
        #expect(abs(scene.cameraValue(.positionX, at: 1) - across - 470) < 1e-6)
        #expect(abs(scene.cameraValue(.scale, at: 3) - scale) < 1e-6 && abs(scene.cameraValue(.positionX, at: 3) - across) < 1e-6)
    }

    @Test func motionDesignHoldsStillForABeatAndAHalfAtMost() throws {
        let still = { (move: String) in
            try MotionLint.findings(in: self.document(self.disc(#"[{"move": "\#(move)", "start": 0.1}, {"move": "press", "start": 1.4}]"#), duration: 2))
                .contains { $0.rule == .stillness }
        }

        // Still from 0.5 to 1.4 s: too long between a pop and a press, fine after a rise
        #expect(try still("pop"))
        #expect(try !still("rise"))
    }
}
