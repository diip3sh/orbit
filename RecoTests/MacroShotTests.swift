//
//  MacroShotTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

/// The approved Supabase film's cameras, made from views instead of keyed by hand (spec 0012): the
/// opening on bare ground, a field typed once and shown typed after, a selection stepped through, a
/// tour whipping from part to part.
struct MacroShotTests {

    private let document = try? JSONDecoder().decode(MotionDocument.self, from: Data(#"""
    {
      "version": 1, "canvas": { "field": "satin" },
      "assets": [
        { "id": "bar", "url": "https://example.com", "selector": "#d", "glass": true, "typing": { "field": "input", "text": "" } },
        { "id": "typed", "url": "https://example.com", "selector": "#d", "glass": true, "typing": { "field": "input", "text": "find issues" } },
        { "id": "results", "url": "https://example.com", "selector": "#d", "glass": true, "typing": { "field": "input", "text": "find issues", "select": 2 } },
        { "id": "card", "url": "https://example.com", "selector": "#card", "glass": true }
      ],
      "scenes": [
        { "id": "open", "duration": 3, "shot": { "shot": "macro", "ui": "bar", "view": [[-40, -20], [200, 112.5]] } },
        { "id": "type", "duration": 4, "shot": { "shot": "macro", "ui": "typed" } },
        { "id": "pick", "duration": 3, "shot": { "shot": "macro", "ui": "results" } },
        { "id": "tour", "duration": 4, "seam": "whip", "shot": { "shot": "macro", "items": [
          { "ui": "card", "view": [[0, 0], [320, 180]] }, { "ui": "card", "view": [[400, 300], [160, 90]] }] } }
      ]
    }
    """#.utf8))

    private let sizes = ["bar": CGSize(width: 600, height: 50), "typed": CGSize(width: 600, height: 300), "results": CGSize(width: 600, height: 300),
                         "card": CGSize(width: 800, height: 500)]

    private func scenes() throws -> [MotionScene] {
        DocumentExpansion.expanded(try #require(document), sizes: sizes).scenes
    }

    private func content(_ layer: MotionLayer) -> UIContent? {
        guard case .lifted(let content) = layer.content else { return nil }
        return content
    }

    /// The opening frames its view: the ground alone for a second, the control cut in, the camera
    /// pulling back from there.
    @Test func theOpeningCutsInOnItsViewAfterABreath() throws {
        let open = try scenes()[0]
        #expect(open.layers.count == 1)
        #expect(open.layers[0].keyframes[.opacity] == [Keyframe(time: 0, value: 0, easing: .hold), Keyframe(time: ShotLayout.macroBreath, value: 1)])
        // The view fills 92 % of the frame: 0.92 × 1920 / 200
        let zoom = 0.92 * 9.6
        #expect(open.camera.position == [60, 36.25, CameraProjection.dolly(forZoom: zoom, canvas: CGSize(width: 1920, height: 1080))])
        #expect(open.camera.moves.map(\.kind) == [.pullBack])
        #expect(open.camera.moves[0].start == ShotLayout.macroBreath)
    }

    /// A field is typed a beat after it shows, and shown typed by a later scene of the same field;
    /// a selection steps down to the lifted results and back, as the film's did.
    @Test func typingCarriesOnAndTheSelectionStepsThroughItsResults() throws {
        let all = try scenes()
        #expect(content(all[0].layers[0])?.typingStart == nil)
        #expect(content(all[1].layers[0])?.typingStart == ShotLayout.macroTypingDelay)
        let pick = try #require(content(all[2].layers[0]))
        #expect(pick.typingStart == ShotLayout.typedBefore)
        #expect(pick.presses?.map(\.key) == [.arrowDown, .arrowDown, .arrowUp, .arrowUp])
        let times = try #require(pick.presses?.map(\.time))
        #expect(zip(times, [0.55, 1.02, 1.6, 1.74]).allSatisfy { abs($0 - $1) < 1e-9 })
        // Without a view, the element's top-left corner in the frame's shape: half of its 600 px across
        #expect(all[1].camera.position?.x == 150)
    }

    /// A tour holds on each view, creeping in, and whips to the next, landing at its framing; never closer
    /// than keeps the element within a lift's 8,192 px.
    @Test func aTourWhipsFromViewToView() async throws {
        let tour = try scenes()[3]
        #expect(tour.layers.count == 1)
        #expect(tour.camera.moves.map(\.kind) == [.push, .whip, .push])
        let hold = (4 - MoveExpansion.whipDuration) / 2
        #expect(abs((tour.camera.moves[1].start ?? 0) - hold) < 1e-9)
        #expect(tour.camera.moves[1].target == CGPoint(x: 480, y: 345))
        // 0.92 × 1080 / 90 = 11.04× would show the 800 px card 8,832 px wide: 8,192 / 800 = 10.24×, from 0.92 × 6
        let first = 0.92 * 6
        #expect(abs((tour.camera.moves[1].intensity ?? 0) - 10.24 / (first * (1 + ShotLayout.macroCreep))) < 1e-9)

        // Unmeasured, the card is 640 px wide, so 11.04× fits
        let plan = await MotionPlan.build(try #require(document), bundle: URL.temporaryDirectory)
        let landed = plan.camera(of: plan.scenes[3], at: hold + MoveExpansion.whipDuration)
        #expect(abs(landed.lookAt.x - 480) < 1e-6 && abs(landed.lookAt.y - 345) < 1e-6)
        #expect(abs(landed.magnification - 11.04) < 1e-6)
    }

    /// A whip seam leaves sideways over the scene's last 0.15 s and comes in from the same side,
    /// a share of the frame whatever the zoom.
    @Test func aWhipSeamStreaksAcrossTheCut() async throws {
        let plan = await MotionPlan.build(try #require(document), bundle: URL.temporaryDirectory)
        let (before, after) = (plan.scenes[2], plan.scenes[3])
        let zoomOut = plan.camera(of: before, at: before.duration).magnification
        let zoomIn = plan.camera(of: after, at: 0).magnification
        let rest = { (scene: MotionPlan.Scene, time: Double) in scene.cameraValue(.positionX, at: time) }
        #expect(abs(rest(before, before.duration) - rest(before, before.duration - 0.15) - 0.5 * 1920 / zoomOut) < 1)
        #expect(abs(rest(after, 0.45) - rest(after, 0) - 0.8 * 1920 / zoomIn) < 1)
    }

    /// Over satin a macro's UI is glass or bare, never the page's own paint.
    @Test func aMacroOverSatinIsGlassOrBare() throws {
        var document = try #require(document)
        #expect(!MotionLint.findings(in: document).contains { $0.rule == .material })
        document.assets[3].glass = nil
        #expect(MotionLint.findings(in: document).filter { $0.rule == .material }.map(\.scene) == ["tour"])
        document.canvas.field = .plain
        #expect(!MotionLint.findings(in: document).contains { $0.rule == .material })
    }

    @Test func aMacroNeedsUIOnEveryStop() {
        var shot = MotionShot(.macro)
        #expect(shot.problem(assets: ["card"]) != nil)
        shot.items = [ShotItem(asset: "card"), ShotItem(text: "No UI")]
        #expect(shot.problem(assets: ["card"]) != nil)
        shot.items = [ShotItem(asset: "card", view: CGRect(x: -20, y: 0, width: 300, height: 170))]
        #expect(shot.problem(assets: ["card"]) == nil)
        var focus = MotionShot(.uiFocus, asset: "card")
        focus.view = CGRect(x: 0, y: 0, width: 10, height: 10)
        #expect(focus.problem(assets: ["card"]) != nil)
    }
}
