//
//  StoryFilmTests.swift
//  RecoTests
//

import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import Reco

/// Story films (spec 0015), after Lovable's chat launch: the aurora's light round a mostly black frame, the brand's
/// gradient, a voice line following its caret, replies word by word, shimmers and washes, a scattered collage, swaps on a
/// beat, a pointer carried over a cut.
struct StoryFilmTests {

    private let bundle = URL.temporaryDirectory

    private let lovable = ["#5b6ff8", "#a783f5", "#f582e9", "#ed3c55", "#ef6720"].compactMap { RGBAColor(hex: $0) }

    private func document(_ layers: String, duration: Double = 4) throws -> MotionDocument {
        var document = MotionDocument(scenes: [MotionScene(
            id: "scene", duration: duration, layers: try JSONDecoder().decode([MotionLayer].self, from: Data(layers.utf8))
        )])
        document.canvas.frameRate = 30
        document.canvas.field = .plain
        document.canvas.background = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
        document.style.gradient = lovable
        return document
    }

    // MARK: - The ground

    @Test func theAuroraLightsEachShotAsTheFilmsFrame() throws {
        let palette = FieldPalette(.aurora, style: StyleTokens(gradient: lovable), background: RGBAColor(red: 0, green: 0, blue: 0, alpha: 1))
        #expect(palette.colors.count == AuroraSetup.core.count + lovable.count)
        let size = CGSize(width: 192, height: 108)
        // Each shot as the film's frame it was fitted to: its ground's black and lit shares, measured with its UI masked, so
        // the whole frame here differs by up to 11 points where the UI covered the dark middle
        let film: [(black: Double, lit: Double)] = [(0.58, 0.30), (0.23, 0.37), (0.72, 0.20), (0.92, 0.014), (0.76, 0.026), (0, 0.83)]
        for (index, expected) in film.enumerated() {
            let image = FieldRenderer.image(.aurora, palette: palette, at: 3, size: size, shot: FieldRenderer.Shot(index: index, start: 2))
            let pixels = try MotionDesignTests.pixels(of: image, size: size)
            let luma = stride(from: 0, to: pixels.count, by: 4).map { 0.2126 * Double(pixels[$0]) + 0.7152 * Double(pixels[$0 + 1]) + 0.0722 * Double(pixels[$0 + 2]) }
            let black = Double(luma.filter { $0 < 8 }.count) / Double(luma.count)
            let lit = Double(luma.filter { $0 >= 40 }.count) / Double(luma.count)
            #expect(abs(black - expected.black) < 0.12 && abs(lit - expected.lit) < 0.12, "shot \(index): black \(black), lit \(lit)")
        }
    }

    @Test func theAuroraGoesOutBeforeTheEnd() {
        #expect(AuroraSetup.light(at: 5, length: 10) == 1)
        #expect(AuroraSetup.light(at: 8.5, length: 10) < 1)
        #expect(AuroraSetup.light(at: 9, length: 10) == 0)
    }

    @Test func aBrandWithoutAGradientGetsOneFromItsAccent() {
        let derived = StyleTokens(accent: RGBAColor(hex: "#1ed760")).brandGradient
        #expect(derived.count == 3 && OKLCH(derived[2]).hue > OKLCH(derived[0]).hue)
        // Without a hue, silver
        #expect(StyleTokens(accent: RGBAColor(hex: "#f7f8f8")).brandGradient.allSatisfy { OKLCH($0).chroma < 0.03 })
        #expect(StyleTokens(gradient: lovable).brandGradient == lovable)
    }

    @Test func aGradientNeedsTwoToFiveColours() throws {
        var document = try document("[]")
        document.style.gradient = [lovable[0]]
        #expect(throws: MotionDocumentError.invalidGradient) { try document.validate() }
    }

    // MARK: - Type

    @Test func aVoiceLineFollowsItsCaret() async throws {
        let text = #"[{"id": "said", "content": {"text": {"text": "I've been making these sauna hats", "size": 110, "weight": "regular"}},"#
            + #" "transform": {"position": [960, 540, 0]}, "moves": [{"move": "voice", "start": 0.1, "duration": 2}]}]"#
        let plan = await MotionPlan.build(try document(text), bundle: bundle)
        let layer = plan.scenes[0].layers[0]
        #expect(layer.reveal?.style == .voice && layer.isSharp)
        // Centred while it fits: its typed part's middle on the anchor
        let early = layer.value(.positionX, at: 0.1 + 2 * 3 / 33)
        #expect(early > 960)
        // Then the caret held at 70 % of the width
        let end = 0.1 + 2.0
        let placement = try #require(plan.placements(of: plan.scenes[0], at: end).first)
        let caret = placement.corners[0].x + (layer.parts.last?.maxX ?? 0)
        #expect(abs(caret - MotionPlan.voiceFollow * 1920) < 2)
    }

    @Test func aReplyArrivesWordByWord() async throws {
        let text = #"[{"id": "reply", "content": {"text": {"text": "Let's explore what the brand could look like", "size": 44}},"#
            + #" "transform": {"position": [960, 540, 0]}, "moves": [{"move": "reply", "start": 0.2}]}]"#
        let layer = await MotionPlan.build(try document(text), bundle: bundle).scenes[0].layers[0]
        let reveal = try #require(layer.reveal)
        #expect(reveal.style == .reply && reveal.tintsInGradient && layer.parts.count == 8)
        #expect(abs(reveal.stagger - MoveExpansion.replyStagger) < 1e-9)
        #expect(layer.gradient == lovable)
    }

    // MARK: - Moves

    @Test func showAndHideSwapOnTheirFrame() async throws {
        let tile = { (id: String, move: String) in
            #"{"id": "\#(id)", "content": {"shape": {"size": [100, 100], "color": "ff0000"}}, "transform": {"position": [960, 540, 0]},"#
                + #" "moves": [{"move": "\#(move)", "start": 1}]}"#
        }
        let tiles = "[\(tile("a", "hide")), \(tile("b", "show"))]"
        let layers = await MotionPlan.build(try document(tiles), bundle: bundle).scenes[0].layers
        #expect(layers[0].value(.opacity, at: 0.99) == 1 && layers[0].value(.opacity, at: 1) == 0)
        #expect(layers[1].value(.opacity, at: 0.99) == 0 && layers[1].value(.opacity, at: 1) == 1)
    }

    /// Under a shutter open across a swap (a moving macro's "Merge all" turning to "Merged"), the frame shows only what its own
    /// moment does: averaged, both labels drew at half.
    @Test func aSwapUnderTheShutterShowsTheFramesOwnMoment() async throws {
        let tile = { (id: String, move: String) in
            #"{"id": "\#(id)", "content": {"shape": {"size": [100, 100], "color": "ff0000"}}, "transform": {"position": [960, 540, 0]},"#
                + #" "moves": [{"move": "\#(move)", "start": 1}]}"#
        }
        let plan = await MotionPlan.build(try document("[\(tile("a", "hide")), \(tile("b", "show"))]"), bundle: bundle)

        #expect(plan.placements(of: plan.scenes[0], at: 0.99, shown: 1.01).map(\.layer) == [1])
        #expect(plan.placements(of: plan.scenes[0], at: 1.01, shown: 0.99).map(\.layer) == [0])
    }

    @Test func aScatterThrowsAGroupsLayersOutFromItsMiddle() async throws {
        let cards = (0..<3).map { index in
            #"{"id": "c\#(index)", "content": {"shape": {"size": [200, 240], "color": "c8402f"}}, "transform": {"position": [\#(index * 300 - 300), 100, 0]}}"#
        }.joined(separator: ", ")
        let group = #"[{"id": "collage", "content": {"group": [\#(cards)]}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "scatter", "start": 0.2}]}]"#
        let layers = await MotionPlan.build(try document(group), bundle: bundle).scenes[0].layers
        let first = layers[1]
        // Stacked in the group's middle, turned and small, then in its place at its own size
        #expect(abs(first.value(.positionX, at: 0.2)) < 1e-6 && abs(first.value(.positionY, at: 0.2)) < 1e-6)
        #expect(abs(first.value(.rotationZ, at: 0.2)) > 5 && first.value(.scale, at: 0.2) < 0.6)
        #expect(abs(first.value(.positionX, at: 1) + 300) < 1e-6 && abs(first.value(.scale, at: 1) - 1) < 1e-6)
        // One after another, the stack there from the cut
        #expect(abs(layers[2].value(.positionX, at: 0.2 + MoveExpansion.scatterStagger)) < 1e-6)
        #expect(layers.dropFirst().allSatisfy { $0.value(.opacity, at: 0) == 1 })
    }

    /// Each transition has its own sound over the ambient chords: the opening's and a seam's dots, the ring's swell, hit and
    /// glasses into the logo, a wash's shimmer, one chime for everything turning to done; a dictated voice types no keys.
    @Test func eachTransitionHasItsSound() async throws {
        let json = ##"""
            {"version": 1, "canvas": {"field": "warp", "fieldStrength": 0.45, "frameRate": 60}, "style": {"accent": "#ffffff"}, "scenes": [
              {"id": "open", "duration": 2.118, "seam": "dither", "layers": [{"id": "box", "content": {"shape": {"size": [1190, 370], "color": "#ffffff0d",
               "glass": true}}, "transform": {"position": [960, 540, 0]}, "moves": [{"move": "wash", "start": 1.4}]}]},
              {"id": "voice", "duration": 2.471, "layers": [{"id": "said", "content": {"text": {"text": "I've got five bugs", "size": 140}},
               "transform": {"position": [960, 540, 0]}, "moves": [{"move": "voice", "start": 0, "duration": 1.5}]}]},
              {"id": "tiles", "duration": 2.824, "seam": "dither", "layers": [
                {"id": "a", "content": {"text": {"text": "Passed", "size": 32}}, "transform": {"position": [700, 540, 0]}, "moves": [{"move": "show", "start": 2.118}]},
                {"id": "b", "content": {"text": {"text": "Passed", "size": 32}}, "transform": {"position": [1200, 540, 0]}, "moves": [{"move": "show", "start": 2.118}]}]},
              {"id": "logo", "duration": 2.824, "seam": "ring", "field": "halo", "layers": [{"id": "name", "content": {"text": {"text": "Orca", "size": 120}},
               "transform": {"position": [960, 540, 0]}}]}]}
            """##
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8))
        let plan = await MotionPlan.build(document, bundle: bundle)
        let cues = plan.sound.cues
        let near = { (time: Double) in { (cue: SoundCue) in abs(cue.time - time) < 0.02 } }

        #expect(plan.sound.finish == nil && !cues.contains { if case .drum = $0.voice { true } else { false } })
        let bits = cues.filter { if case .bits = $0.voice { true } else { false } }.map(\.time)
        #expect(bits.count == 2 && near(MotionFrameRenderer.groundSwell)(cues.first { if case .bits = $0.voice { true } else { false } }!))
        let tiles = plan.scenes[2].start, logo = plan.scenes[3].start
        #expect(bits.contains { abs($0 - tiles) < 0.02 })
        #expect(cues.contains { if case .riser = $0.voice { near(logo)($0) } else { false } } && cues.contains { if case .thump = $0.voice { near(logo)($0) } else { false } })
        #expect(cues.contains { if case .riser = $0.voice { near(1.4 + SoundRules.washShimmer.crossed)($0) } else { false } })
        let chimes = cues.filter { if case .blip(let note, _) = $0.voice { note == SoundRules.doneChime.notes[0] } else { false } }
        #expect(chimes.count == 1 && near(tiles + 2.118)(chimes[0]))
        #expect(!cues.contains { if case .key = $0.voice { true } else { false } })
        // Its cuts a quieter swish alone
        let cut = plan.scenes[1].start
        #expect(cues.filter(near(cut)).map(\.level) == [SoundRules.cutSwish.level + SoundRules.softCut])
    }

    /// A scene's clicks share one pointer: the first's goes as the next's comes on, and that one travels from where the first
    /// was rather than rising from below.
    @Test func clicksShareOnePointer() async throws {
        let row = #"[{"id": "row", "content": {"shape": {"size": [600, 120], "color": "333333"}}, "transform": {"position": [960, 540, 0]},"#
            + #" "moves": [{"move": "click", "start": 0.53}, {"move": "click", "start": 1.06}]}]"#
        let plan = await MotionPlan.build(try document(row, duration: 2), bundle: bundle)
        try #require(plan.pointer != nil)
        let clicks = plan.scenes[0].layers[0].clicks
        let handover = MotionPointer.appears(clicks[1]) + 0.01
        let tips = MotionFrameRenderer.pointerTips(of: plan.scenes[0], at: handover, plan: plan).compactMap { $0 }
        #expect(tips.count == 1)
        // Still where the first pressed, not below the frame
        #expect(tips.first.map { $0.y < plan.canvas.height } == true)
    }

    /// A glass card is a pane over the field in its own shape; an outline or a glyph isn't.
    @Test func aGlassCardIsAPaneInItsShape() async throws {
        let card = { (id: String, extra: String) in
            ##"{"id": "\##(id)", "content": {"shape": {"size": [400, 250], "cornerRadius": 28, "color": "#ffffff0d", "glass": true\##(extra)}}, "##
                + ##""transform": {"position": [960, 540, 0]}}"##
        }
        let layers = await MotionPlan.build(try document("[\(card("pane", "")), \(card("outline", #", "stroke": 2"#))]"), bundle: bundle).scenes[0].layers
        #expect(layers[0].glass == GlassRenderer.Shape(radius: 28, rim: GlassRenderer.shapeRim))
        #expect(layers[1].glass == nil)
    }

    /// A wash's light grows out of the bottom-right corner, where the send is, and is gone at its end.
    @Test func aWashGrowsOutOfItsCorner() async throws {
        let box = ##"[{"id": "box", "content": {"group": [{"id": "fill", "content": {"shape": {"size": [1600, 800], "color": "#141414"}}, "##
            + ##""transform": {"position": [0, 0, 0]}}]},"##
            + #" "transform": {"position": [960, 540, 0]}, "moves": [{"move": "wash", "start": 0}]}]"#
        let plan = await MotionPlan.build(try document(box, duration: 2), bundle: bundle, shorterSide: 135)
        let light = { (time: Double, across: Int, down: Int) in
            let pixels = try MotionDesignTests.pixels(of: MotionFrameRenderer.image(at: time, plan: plan), size: plan.outputSize)
            return Int(pixels[(down * Int(plan.outputSize.width) + across) * 4])
        }
        // Rows from the top: the bottom-right corner lit first, the top-left still dark
        #expect(try light(0.15, 214, 112) > light(0.15, 26, 23) + 40)
        #expect(try light(0.5, 26, 23) > light(0, 26, 23) + 20)
        #expect(try abs(light(1.25, 26, 23) - light(0, 26, 23)) <= 2)
    }

    @Test func aWashGoesToItsGroupsLayersAndAShimmerStaysOnItsOwn() async throws {
        let box = #"[{"id": "box", "content": {"group": [{"id": "fill", "content": {"shape": {"size": [800, 300], "color": "141414"}}, "transform": {"position": [0, 0, 0]}},"#
            + #" {"id": "label", "content": {"text": {"text": "Thinking…", "size": 40}}, "transform": {"position": [0, 0, 0]}, "moves": [{"move": "shimmer", "start": 0.2}]}]},"#
            + #" "transform": {"position": [960, 540, 0]}, "moves": [{"move": "wash", "start": 1}]}]"#
        let layers = await MotionPlan.build(try document(box, duration: 3), bundle: bundle).scenes[0].layers
        #expect(layers.allSatisfy { $0.tints.contains { $0.kind == .wash && $0.over == 0 && abs($0.duration - MoveExpansion.washDuration) < 1e-9 } })
        #expect(layers[2].tints.contains { $0.kind == .shimmer && abs($0.duration - 2.8) < 1e-9 })
        #expect(!layers[1].tints.contains { $0.kind == .shimmer })
    }

    @Test func underABeatEverySceneIsWholeBeats() throws {
        var document = try document("[]", duration: 2.6)
        #expect(!MotionLint.findings(in: document).contains { $0.rule == .beats })
        document.sound.style = .groove
        let finding = try #require(MotionLint.findings(in: document).first { $0.rule == .beats })
        #expect(finding.message.contains("2.471") && finding.message.contains("2.824"))
        document.scenes[0].duration = 7 * 60 / 170
        #expect(!MotionLint.findings(in: document).contains { $0.rule == .beats })
    }

    @Test func theMovesKnowWhatTheyNeed() {
        let shape = LayerContent.shape(ShapeContent(size: CGSize(width: 10, height: 10), color: RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)))
        #expect(MotionMove(.scatter).problem(on: shape) != nil)
        #expect(MotionMove(.voice).problem(on: shape) != nil)
        #expect(MotionMove(.shimmer).problem(on: shape) == nil && MotionMove(.show).problem(on: shape) == nil)
    }

    @Test func aPressEarlyInAShotHasThePointerThereFromTheCut() {
        let corners = [CGPoint(x: 860, y: 500), CGPoint(x: 1060, y: 500), CGPoint(x: 1060, y: 580), CGPoint(x: 860, y: 580)]
        let canvas = CGSize(width: 1920, height: 1080)
        let carried = MotionPointer.tip(of: MotionPlan.Click(press: 0.4, leaves: 1), on: corners, at: 0, canvas: canvas)
        #expect(carried?.point == MotionPointer.tip(of: MotionPlan.Click(press: 0.4, leaves: 1), on: corners, at: 0.4, canvas: canvas)?.point)
        #expect(MotionPointer.tip(of: MotionPlan.Click(press: 1, leaves: 1.5), on: corners, at: 0, canvas: canvas) == nil)
    }

    /// Dark type on a light tile is read against the tile, through a translucent chip over it; on the black ground it isn't.
    @Test func typeOnATileIsReadAgainstTheTile() throws {
        func contrastFindings(_ tile: String) throws -> Int {
            let layers = #"""
            [{"id": "tile", "content": {"group": [
              {"id": "fill", "content": {"shape": {"size": [400, 245], "cornerRadius": 34, "color": "\#(tile)"}}, "transform": {"position": [0, 0, 0]}},
              {"id": "chip", "content": {"shape": {"size": [150, 50], "cornerRadius": 25, "color": "#0000001a"}}, "transform": {"position": [95, -65, 0]}},
              {"id": "label", "content": {"text": {"text": "Running", "size": 26, "color": "#111111", "weight": "medium"}}, "transform": {"position": [95, -65, 0]}}
            ]}, "transform": {"position": [960, 540, 0]}}]
            """#
            return MotionLint.findings(in: try document(layers)).filter { $0.rule == .contrast }.count
        }
        #expect(try contrastFindings("#f2f2f2") == 0)
        #expect(try contrastFindings("#000000") == 1)
    }

    /// A brand's mark published as an SVG is lifted from a page of that one image; a page's address is loaded as itself.
    @Test func anImageAddressIsLiftedFromAPageOfItsOwn() throws {
        let mark = try #require(URL(string: "https://cdn.jsdelivr.net/npm/simple-icons@latest/icons/claude.svg"))
        let page = try #require(WebPageRenderer.imagePage(for: mark))
        #expect(page.contains(#"<img src="\#(mark.absoluteString)""#))
        #expect(WebPageRenderer.imagePage(for: try #require(URL(string: "https://www.onorca.dev/docs"))) == nil)
    }

    /// A tinted lift keeps its alpha and takes the tint's colour: half-covered red becomes half-covered white.
    @Test func aTintPaintsALiftInOneColour() throws {
        let red = CIImage(color: CIColor(red: 0.5, green: 0, blue: 0, alpha: 0.5)).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
        let tinted = MotionPlan.tinted(red, RGBAColor(red: 1, green: 1, blue: 1, alpha: 1))
        var pixel = [Float](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(
            tinted, toBitmap: &pixel, rowBytes: 16, bounds: tinted.extent, format: .RGBAf, colorSpace: nil
        )
        #expect(pixel.map { ($0 * 100).rounded() / 100 } == [0.5, 0.5, 0.5, 0.5])
    }
}
