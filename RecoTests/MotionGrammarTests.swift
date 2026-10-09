//
//  MotionGrammarTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

/// The grammar's easings, moves, seams, shots and lint (spec 0011, phase 3).
struct MotionGrammarTests {

    private let canvas = CGSize(width: 1920, height: 1080)

    private func context(duration: Double = 3, characters: Int = 0, lines: Int = 0) -> MoveContext {
        var context = MoveContext(sceneDuration: duration, canvas: canvas)
        (context.characters, context.lines) = (characters, lines)
        return context
    }

    // MARK: - Easings

    @Test func longSettleStartsFastAndLands() {
        let settle = MotionEasing.longSettle
        #expect(settle.progress(0, duration: 4.5) == 0)
        #expect(abs(settle.progress(1, duration: 4.5) - 1) < 1e-9)
        // Framer: half done at 0.65 s of a 4.5 s pull-back
        #expect(abs(settle.progress(0.65 / 4.5, duration: 4.5) - 0.5) < 0.03)
        let encoded = try? JSONEncoder().encode(settle)
        #expect(encoded.flatMap { String(data: $0, encoding: .utf8) } == #"{"settle":0.9}"#)
    }

    @Test func noGrammarEasingOvershoots() {
        for easing in [MotionEasing.enter, .enterFast, .cascade, .exit, .move, .longSettle] {
            let values = (0...100).map { easing.progress(Double($0) / 100, duration: 1) }
            #expect(values.allSatisfy { (-1e-9...1 + 1e-9).contains($0) })
            #expect(zip(values, values.dropFirst()).allSatisfy { $0 <= $1 + 1e-9 })
        }
    }

    @Test func aLongPanZoomsOutOnTheWay() {
        let path = ZoomPath(from: CGPoint(x: 0, y: 0), width: 1920, to: CGPoint(x: 3840, y: 0), width: 1920)
        #expect(abs(path.view(at: 0).center.x) < 1e-6)
        #expect(abs(path.view(at: 1).center.x - 3840) < 1e-6)
        #expect(abs(path.view(at: 1).width - 1920) < 1e-6)
        #expect(path.view(at: 0.5).width > 1920 * 1.2)
    }

    // MARK: - Moves

    @Test func fadeUpEntersFromBelowAfterTheCut() {
        let effect = MoveExpansion.effect(of: MotionMove(.fadeUp), in: context())
        let opacity = effect.tracks[.opacity]?.first
        #expect(opacity?.value(at: 0) == 0)
        #expect(opacity?.keyframes.first?.time == MoveExpansion.entranceStart)
        #expect(opacity?.value(at: 1) == 1)
        #expect(effect.tracks[.positionY]?.first?.value(at: 0) == 16)
        #expect(effect.tracks[.positionY]?.first?.value(at: 1) == 0)
    }

    @Test func anExitEndsTheSceneAndIsShorterThanAnEntrance() {
        let exit = MoveExpansion.timing(of: MotionMove(.exit), in: context(duration: 3))
        let entrance = MoveExpansion.timing(of: MotionMove(.fadeUp), in: context(duration: 3))
        #expect(exit.start + exit.duration == 3)
        #expect(exit.duration < entrance.duration)
    }

    @Test func typingRevealsFifteenCharactersASecond() throws {
        let reveal = try #require(MoveExpansion.effect(of: MotionMove(.type), in: context(characters: 30)).reveal)
        #expect(reveal.style == .type)
        let start = MoveExpansion.entranceStart
        #expect(reveal.progress(ofPart: 14, at: start + 14.0 / 15 - 0.01) == 0)
        #expect(reveal.progress(ofPart: 14, at: start + 14.0 / 15 + 0.01) == 1)
        #expect(abs(reveal.end(parts: 30) - (start + 29.0 / 15)) < 1e-9)
    }

    @Test func aWipeTakes44MillisecondsACharacter() throws {
        let reveal = try #require(MoveExpansion.effect(of: MotionMove(.blurWipe), in: context(characters: 11)).reveal)
        #expect(reveal.style == .wipe)
        #expect(abs(reveal.stagger - 0.044) < 1e-9)
        #expect(reveal.progress(ofPart: 0, at: 0.35) > 0 && reveal.progress(ofPart: 0, at: 0.35) < 1)
    }

    @Test func driftIsSteadyAndOutlastsItsScene() {
        let effect = MoveExpansion.effect(of: MotionMove(.drift), in: context(duration: 2))
        let pan = effect.tracks[.positionX]?.first
        // 2% of the width a second, at constant speed
        #expect(abs((pan?.value(at: 1) ?? 0) - 0.02 * 1920) < 1e-6)
        #expect((pan?.keyframes.last?.time ?? 0) == 2 + MoveExpansion.driftOverrun)
    }

    @Test func aLongScenesDriftSlowsSoItsCaptionsStayInFrame() {
        let effect = MoveExpansion.effect(of: MotionMove(.drift), in: context(duration: 10))
        let pan = effect.tracks[.positionX]?.first
        let zoom = effect.tracks[.scale]?.first
        #expect(abs((pan?.value(at: 10) ?? 0) - MoveExpansion.longestDrift * 1920) < 1e-6)
        #expect((zoom?.value(at: 10) ?? 2) < 1.025)
    }

    @Test func aPanEndsOnItsTargetAtItsZoom() {
        var pan = MotionMove(.pan, start: 0)
        pan.target = CGPoint(x: 1400, y: 300)
        pan.intensity = 2
        var context = context()
        context.lookAt = CGPoint(x: 960, y: 540)
        let effect = MoveExpansion.effect(of: pan, in: context)
        let end = MoveExpansion.timing(of: pan, in: context).duration
        #expect(abs((effect.tracks[.positionX]?.first?.value(at: end) ?? 0) - 440) < 1e-6)
        #expect(abs((effect.tracks[.positionY]?.first?.value(at: end) ?? 0) + 240) < 1e-6)
        #expect(abs((effect.tracks[.scale]?.first?.value(at: end) ?? 0) - 2) < 1e-6)
    }

    @Test func movesAreValidatedWhereTheyAre() {
        #expect(MotionMove(.drift).problem(on: nil) == nil)
        #expect(MotionMove(.drift).problem(on: .shape(ShapeContent(size: CGSize(width: 1, height: 1), color: .init(red: 1, green: 1, blue: 1, alpha: 1)))) != nil)
        #expect(MotionMove(.fadeUp).problem(on: nil) != nil)
        #expect(MotionMove(.type).problem(on: .group([])) != nil)
        #expect(MotionMove(.cascade).problem(on: .group([])) == nil)
        #expect(MotionMove(.roll).problem(on: .text(TextContent(text: "A"))) != nil)
        #expect(MotionMove(.fadeUp, duration: 0).problem(on: .text(TextContent(text: "A"))) != nil)
    }

    // MARK: - Plans

    @Test func movesAddToTheBaseAndKeyframesOverrideThem() async {
        var layer = MotionLayer(id: "box", content: .shape(ShapeContent(size: CGSize(width: 100, height: 100), color: .init(red: 1, green: 1, blue: 1, alpha: 1))))
        layer.transform.position = [500, 500, 0]
        layer.moves = [MotionMove(.fadeUp, start: 0, duration: 1), MotionMove(.exit, start: 2, duration: 0.5)]
        var document = MotionDocument(scenes: [MotionScene(id: "one", duration: 3, layers: [layer])])
        var plan = await MotionPlan.build(document, bundle: URL.temporaryDirectory)
        let built = plan.scenes[0].layers[0]
        #expect(abs(built.value(.positionY, at: 0) - 516) < 1e-6)
        #expect(built.value(.positionY, at: 1.5) == 500)
        #expect(built.value(.opacity, at: 1.5) == 1)
        #expect(built.value(.opacity, at: 2.5) == 0)

        document.scenes[0].layers[0].keyframes[.opacity] = [Keyframe(time: 0, value: 0.5)]
        plan = await MotionPlan.build(document, bundle: URL.temporaryDirectory)
        #expect(plan.scenes[0].layers[0].value(.opacity, at: 2.5) == 0.5)
    }

    @Test func seamsMoveTheCamerasEitherSide() async {
        let still = MotionScene(id: "one", duration: 2)
        var through = MotionScene(id: "two", duration: 2)
        through.seam = .zoomThrough
        var pushed = MotionScene(id: "three", duration: 2)
        pushed.seam = .push
        let plan = await MotionPlan.build(MotionDocument(scenes: [still, through, pushed]), bundle: URL.temporaryDirectory)

        #expect(plan.scenes[0].cameraValue(.scale, at: 1.7) == 1)
        #expect(abs(plan.scenes[0].cameraValue(.scale, at: 2) - 1.2) < 1e-9)
        #expect(plan.scenes[0].cameraValue(.blur, at: 2) > 0)
        #expect(abs(plan.scenes[1].cameraValue(.scale, at: 0) - 0.75) < 1e-9)
        #expect(plan.scenes[1].cameraValue(.scale, at: 0.5) == 1)
        #expect(plan.scenes[2].transition == SeamExpansion.Transition(seam: .push, duration: 0.5))
        #expect(plan.scenes[1].overlap == 0.5)
    }

    @Test func aCutOnMotionCarriesTheCamerasSpeed() async {
        var drifting = MotionScene(id: "one", duration: 2)
        drifting.camera.moves = [MotionMove(.drift)]
        var next = MotionScene(id: "two", duration: 2)
        next.seam = .cutOnMotion
        let plan = await MotionPlan.build(MotionDocument(scenes: [drifting, next]), bundle: URL.temporaryDirectory)

        let speed = (plan.scenes[1].cameraValue(.positionX, at: 0.01) - plan.scenes[1].cameraValue(.positionX, at: 0)) / 0.01
        #expect(abs(speed - 0.02 * 1920) < 2)
        let later = (plan.scenes[1].cameraValue(.positionX, at: 1.01) - plan.scenes[1].cameraValue(.positionX, at: 1)) / 0.01
        #expect(later < speed / 5)
    }

    // MARK: - Shots

    @Test func shotsLayOutTheirSlots() throws {
        let (_, document) = try decodedGrammar()
        let expanded = DocumentExpansion.expanded(document, sizes: ["card": CGSize(width: 600, height: 350)])

        let title = expanded.scenes[0]
        #expect(title.layers.map(\.id) == ["title.headline", "title.detail"])
        #expect(title.layers[0].moves.map(\.kind) == [.blurWipe])
        #expect(title.camera.moves.map(\.kind) == [.drift])
        // The end card is still
        #expect(expanded.scenes[7].camera.moves.isEmpty)
        // A cascade's rows rise in turn, all within 0.5 s
        guard case .group(let rows) = expanded.scenes[4].layers[0].content else {
            Issue.record("Not a group")
            return
        }
        let starts = rows.compactMap { $0.moves.first?.start }
        #expect(starts.count == 2 && abs(starts[1] - starts[0] - DocumentExpansion.cascadeStagger) < 1e-9)
        // A roll is the line before the last word, then the words in its place
        guard case .group(let parts) = expanded.scenes[6].layers[0].content else {
            Issue.record("Not a group")
            return
        }
        #expect(parts.map(\.id) == ["agents.prefix", "agents.roll0", "agents.roll1", "agents.roll2"])
        // The centred line's prefix ends a space before the rolling word, not at the box's left edge
        guard case .text(let prefix) = parts[0].content, let prefixEnd = TextImage(prefix, scale: 0).words.last?.maxX else {
            Issue.record("No prefix text")
            return
        }
        let gap = parts[1].transform.position[0] - (parts[0].transform.position[0] + prefixEnd)
        #expect(gap > 0 && gap < 0.4 * prefix.size)
    }

    @Test func theBrandsFaceChoosesTheHeadlinesReveal() {
        #expect(ShotLayout.headlineMove(for: .sans) == .blurWipe)
        #expect(ShotLayout.headlineMove(for: .serif) == .lineMask)
        #expect(ShotLayout.headlineMove(for: .mono) == .type)
    }

    @Test func aScenesOwnLayerReplacesTheShotsByID() throws {
        var (_, document) = try decodedGrammar()
        var replacement = MotionLayer(id: "title.headline", content: .text(TextContent(text: "Mine")))
        replacement.transform.position = [100, 100, 0]
        document.scenes[0].layers = [replacement]
        let expanded = DocumentExpansion.expanded(document, sizes: [:])
        #expect(expanded.scenes[0].layers.map(\.id) == ["title.headline", "title.detail"])
        #expect(expanded.scenes[0].layers[0].content == .text(TextContent(text: "Mine")))
    }

    @Test func shotsAreValidated() {
        #expect(MotionShot(.title).problem(assets: []) != nil)
        #expect(MotionShot(.uiHero, asset: "card").problem(assets: []) != nil)
        #expect(MotionShot(.uiHero, asset: "card").problem(assets: ["card"]) == nil)
        #expect(MotionShot(.endCard, text: "Reco").problem(assets: []) == nil)
        var closing = MotionShot(.closing, text: "Supabase")
        #expect(closing.problem(assets: []) != nil)
        closing.items = [ShotItem(text: "Auth")]
        #expect(closing.problem(assets: []) == nil)
    }

    /// The film's closing: the name at 0.32 of the width, each word right-aligned at 0.68 for 0.42 s,
    /// cut in and out; the last held 0.74 s, then both sliding together over 1.4 s into a centred line;
    /// the line under it 0.3 s later, the logo alone 1.55 s after that. Caps 2.5 % of the frame tall.
    @Test func closesAsRaycastsFilmDoes() throws {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(#"""
        {
          "version": 1, "style": { "text": "#ededed" },
          "assets": [{ "id": "logo", "url": "https://supabase.com", "selector": "img" }],
          "scenes": [{ "id": "end", "duration": 9, "shot": { "shot": "closing", "text": "Supabase", "detail": "Build in a weekend", "ui": "logo",
                       "items": [{ "text": "Auth" }, { "text": "Storage" }, { "text": "Docs" }] } }]
        }
        """#.utf8))
        let layers = DocumentExpansion.expanded(document, sizes: ["logo": CGSize(width: 96, height: 18.66)]).scenes[0].layers
        let opacity = { (id: String, time: Double) in
            PropertyTrack(.opacity, keyframes: layers.first { $0.id == id }?.keyframes[.opacity] ?? [])?.value(at: time) ?? -1
        }
        let left = { (id: String, time: Double) in
            PropertyTrack(.positionX, keyframes: layers.first { $0.id == id }?.keyframes[.positionX] ?? [])?.value(at: time) ?? -1
        }

        #expect(layers.map(\.id) == ["end.name", "end.word0", "end.word1", "end.word2", "end.detail", "end.logo"])
        guard case .text(let name) = layers[0].content else {
            Issue.record("No name")
            return
        }
        #expect(name.text == "SUPABASE" && name.face == .mono && abs(name.size * 0.7 - 27) < 0.01)
        #expect(opacity("end.name", 0.2) == 0 && opacity("end.word0", 0.3) == 1 && opacity("end.word0", 0.7) == 0 && opacity("end.word1", 0.7) == 1)
        // The last word from 1.09 s, held till 1.83, then sliding till 3.23; the line at 3.53, the logo at 5.08
        #expect(opacity("end.word2", 1.1) == 1 && left("end.word2", 1.8) == 0.68 * 1920 && left("end.name", 1.8) == 0.32 * 1920)
        #expect(abs(left("end.name", 3.3) + left("end.word2", 3.3) - 1920) < 1e-9)
        #expect(opacity("end.detail", 3.5) == 0 && opacity("end.detail", 3.6) == 1)
        #expect(opacity("end.name", 5.1) == 0 && opacity("end.logo", 5.0) == 0 && opacity("end.logo", 5.1) == 1)
    }

    // MARK: - Lint

    @Test func theGrammarsOwnShotsPassTheirRules() throws {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(#"""
        {
          "version": 1,
          "scenes": [
            { "id": "title", "duration": 3.4, "shot": { "shot": "title", "text": "Ship faster.", "detail": "Plans that keep up" } },
            { "id": "end", "duration": 3.6, "shot": { "shot": "endCard", "text": "Made with Reco", "detail": "reco.app" } }
          ]
        }
        """#.utf8))
        #expect(MotionLint.findings(in: document).isEmpty)
    }

    @Test func aFeatureSequencesItemsLeaveInTurn() throws {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(#"""
        {
          "version": 1,
          "assets": [{ "id": "card", "url": "https://example.com", "selector": "#card" }],
          "scenes": [
            { "id": "features", "duration": 9, "shot": { "shot": "featureSequence", "items": [
              { "text": "Plan the launch", "ui": "card" }, { "text": "Ship it on time", "ui": "card" }, { "text": "Measure it", "ui": "card" }
            ] } }
          ]
        }
        """#.utf8))
        let findings = MotionLint.findings(in: document, sizes: ["card": CGSize(width: 800, height: 500)])
        #expect(!findings.contains { $0.rule == .simultaneousMoves })
    }

    @Test func lintFindsWhatTheRulesForbid() throws {
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(#"""
        {
          "version": 1,
          "scenes": [
            { "id": "hook", "duration": 1, "shot": { "shot": "hook", "text": "One two three four five six seven" } },
            {
              "id": "busy", "duration": 6,
              "layers": [
                { "id": "a", "content": { "text": { "text": "Tiny", "size": 20 } }, "transform": { "position": [960, 540, 0] },
                  "moves": [{ "move": "fadeUp", "start": 0 }, { "move": "exit", "start": 1, "duration": 0.8 }] },
                { "id": "b", "content": { "text": { "text": "Dark", "color": { "red": 0.05, "green": 0.05, "blue": 0.05, "alpha": 1 } } },
                  "transform": { "position": [10, 540, 0] }, "moves": [{ "move": "fadeUp", "start": 0.02 }] },
                { "id": "c", "content": { "text": { "text": "Typed much too quickly here" } }, "transform": { "position": [960, 300, 0] },
                  "moves": [{ "move": "type", "start": 0.05, "duration": 0.5 }] }
              ]
            },
            { "id": "end", "duration": 3.6, "shot": { "shot": "endCard", "text": "Made with Reco", "detail": "reco.app" } }
          ]
        }
        """#.utf8))
        let rules = Set(MotionLint.findings(in: document).map(\.rule))
        let expected: Set<MotionLint.Rule> = [
            .hookLength, .readingTime, .textSize, .contrast, .safeArea, .firstMove, .simultaneousMoves, .exitLength, .typingRate, .stillness
        ]
        #expect(rules == expected)
    }

    @Test func readingTimeGrowsWithWords() {
        #expect(ReadingTime.hold(for: "Ship") == ReadingTime.oneWordHold)
        #expect(ReadingTime.hold(for: "Ship it") == ReadingTime.shortestHold)
        #expect(abs(ReadingTime.hold(for: "one two three four five six seven eight nine ten") - 10 / 3.1) < 1e-9)
    }

    @Test func contrastIsWCAGs() {
        let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
        let black = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
        #expect(abs(LayoutRules.contrast(white, black) - 21) < 1e-9)
        #expect(LayoutRules.contrast(white, white) == 1)
    }

    private func decodedGrammar() throws -> (Data, MotionDocument) {
        let data = try Fixture.data("motion-grammar")
        return (data, try JSONDecoder().decode(MotionDocument.self, from: data))
    }
}
