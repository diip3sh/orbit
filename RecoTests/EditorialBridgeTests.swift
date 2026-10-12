//
//  EditorialBridgeTests.swift
//  RecoTests
//

import CoreImage
import Foundation
import Testing
@testable import Reco

/// What carries an editorial film across its cuts and keeps it from holding still (spec 0018), against ElevenLabs' film as
/// measured: a line eaten into a block at its cut, every scene but the last breathing, the ground darkening into the dark beat.
struct EditorialBridgeTests {

    /// A line eaten by two bars into its scene's cut: its letters there before, gone from its ends after, one block in the
    /// middle at the end.
    @Test func aLineIsEatenIntoABlockAtTheCut() async throws {
        let plan = try await Self.plan("""
            {"id": "one", "duration": 1, "field": "paper", "layers": [
              {"id": "line", "content": {"text": {"text": "Your agents", "size": 68, "color": "#1b1a19"}},
               "transform": {"position": [960, 540, 0], "anchor": [0.5, 0.5]}, "moves": [{"move": "eat", "color": "#000000"}]}
            ]}
            """)
        let eat = try #require(plan.scenes[0].layers.first?.eat)
        #expect(abs(eat.start - (1 - MoveExpansion.eatDuration)) < 1e-9 && eat.duration == MoveExpansion.eatDuration)
        // The line's left half, a quarter of the canvas here: letters before, paper and the closing bar only after
        let leftHalf = CGRect(x: 196, y: 129, width: 40, height: 12)
        #expect(try Self.darkPixels(in: MotionFrameRenderer.image(at: 0.5, plan: plan), rect: leftHalf) > 20)
        let eaten = MotionFrameRenderer.image(at: 0.999, plan: plan)
        #expect(try Self.darkPixels(in: eaten, rect: CGRect(x: 196, y: 129, width: 30, height: 12)) == 0)
        // The two bars meeting in the middle
        #expect(try Self.darkPixels(in: eaten, rect: CGRect(x: 236, y: 130, width: 2, height: 8)) == 16)
        #expect(try Self.darkPixels(in: eaten, rect: CGRect(x: 241, y: 130, width: 2, height: 8)) == 16)
    }

    /// Every scene without a camera of its own breathes: in at 1.04×, half settled in 0.12 s, creeping and leaving faster into
    /// its cut. A scene with its own camera keeps it, and the last scene holds still.
    @Test func everySceneButTheLastBreathes() async throws {
        let plan = try await Self.plan("""
            {"id": "one", "duration": 2, "field": "paper", "layers": []},
            {"id": "two", "duration": 2, "field": "paper", "layers": [], "camera": {"moves": [{"move": "pullBack"}]}},
            {"id": "end", "duration": 2, "field": "paper", "layers": []}
            """)
        let breathing = plan.scenes[0]
        #expect(abs(breathing.cameraValue(.scale, at: 0) - MoveExpansion.breathSettle.from) < 1e-6)
        let half = breathing.cameraValue(.scale, at: 0.12)
        #expect(half > 1.015 && half < 1.03, "\(half)")
        let (late, last) = (breathing.cameraValue(.scale, at: 1.5), breathing.cameraValue(.scale, at: 2))
        #expect(late > 1.015 && last > late + 0.02, "\(late) \(last)")
        #expect(plan.scenes[1].cameraMoves[.scale]?.count == 1)
        #expect(plan.scenes[2].cameraValue(.scale, at: 1) == 1)
    }

    /// A fade in an editorial film is the ground darkening in 11 frames, eased out; elsewhere it's still a dissolve.
    @Test func aFadeIsTheGroundDarkening() async throws {
        let scenes = """
            {"id": "one", "duration": 1, "field": "%@", "layers": []},
            {"id": "dark", "duration": 1, "seam": "fade", "layers": []}
            """
        let darkening = try #require(try await Self.plan(scenes.replacing("%@", with: "paper")).scenes[1].transition)
        #expect(darkening.duration == SeamExpansion.darkenDuration && darkening.progress(at: darkening.duration / 2) > 0.8)
        let dissolve = try #require(try await Self.plan(scenes.replacing("%@", with: "plain")).scenes[1].transition)
        #expect(dissolve.duration == 0.5 && dissolve.progress(at: 0.25) == 0.5)
    }

    /// A line eaten into the cut leaves when the bars start: held long enough, the lint is quiet; eaten early, it says so.
    @Test func theLintReadsAnEatAsLeaving() throws {
        let findings = { (eat: String) in
            MotionLint.findings(in: try JSONDecoder().decode(MotionDocument.self, from: Data(Self.document("""
                {"id": "one", "duration": 3, "field": "paper", "layers": [
                  {"id": "line", "content": {"text": {"text": "Elevate your customer experiences", "size": 68, "color": "#1b1a19"}},
                   "transform": {"position": [960, 540, 0], "anchor": [0.5, 0.5]}, "moves": [{"move": "brighten", "start": 0}, \(eat)]}
                ]}
                """).utf8))).filter { $0.rule == .readingTime }
        }
        #expect(try findings(#"{"move": "eat"}"#).isEmpty)
        #expect(try findings(#"{"move": "eat", "start": 1.3}"#).count == 1)
    }

    private static func document(_ scenes: String) -> String {
        ##"{"version": 1, "canvas": {"size": [1920, 1080], "frameRate": 60, "background": "#f3f2f0"}, "scenes": ["## + scenes + "]}"
    }

    private static func plan(_ scenes: String) async throws -> MotionPlan {
        await MotionPlan.build(try JSONDecoder().decode(MotionDocument.self, from: Data(document(scenes).utf8)), bundle: URL.temporaryDirectory, shorterSide: 270)
    }

    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    /// How many pixels of `rect` (Core Image's coordinates, from the bottom left) are dark.
    private static func darkPixels(in image: CIImage, rect: CGRect) throws -> Int {
        var bytes = [UInt8](repeating: 0, count: Int(rect.width * rect.height) * 4)
        context.render(image, toBitmap: &bytes, rowBytes: Int(rect.width) * 4, bounds: rect, format: .RGBA8, colorSpace: nil)
        return stride(from: 0, to: bytes.count, by: 4).filter { bytes[$0] < 100 && bytes[$0 + 1] < 100 && bytes[$0 + 2] < 100 }.count
    }
}
