//
//  EditorialFilmTests.swift
//  RecoTests
//

import CoreImage
import Foundation
import Testing
@testable import Reco

/// Editorial films (spec 0017), against ElevenLabs' launch film as measured: statements lit word by word, a wordmark opening
/// out of its mark, labels blinking in, a card growing to fill the frame, stars, dots, registration marks, the wipe, the lint
/// and the sound.
struct EditorialFilmTests {

    private static let canvas = CGSize(width: 1920, height: 1080)

    /// "to the standards you set" lit as the film lit it: its words 0.117, 0.3, 0.683 and 0.833 s after the first; dim before,
    /// the line shrinking from 1.19× to its size.
    @Test func aStatementLightsWordByWordAsTheFilmDid() throws {
        let layer = try Self.layer(#"{"id": "s", "content": {"text": {"text": "to the standards you set", "size": 92}}, "moves": [{"move": "brighten", "start": 0.1}]}"#)
        let context = MoveContext(sceneDuration: 3, canvas: Self.canvas, layer: layer)
        #expect(context.wordLengths == [2, 3, 9, 3, 3])
        let effect = MoveExpansion.effect(of: layer.moves[0], in: context)
        let reveal = try #require(effect.reveal)
        let film = [0, 0.117, 0.3, 0.683, 0.833]
        for (index, measured) in film.enumerated() {
            #expect(abs(reveal.start(ofPart: index) - reveal.start(ofPart: 0) - measured) < 0.04, "word \(index)")
        }
        #expect(abs(reveal.start(ofPart: 0) - 0.1 - MoveExpansion.brightenFirst) < 1e-9)
        #expect(reveal.fraction(ofPart: 1, at: reveal.start(ofPart: 1) - 0.01) == 0 && reveal.fraction(ofPart: 1, at: reveal.start(ofPart: 1)) == 1)
        let scale = try #require(effect.tracks[.scale]?.first)
        #expect(abs(scale.value(at: 0) - 1.19) < 1e-6 && abs(scale.value(at: 0.1 + MoveExpansion.brightenSettle) - 1) < 1e-6)
    }

    /// A sweep's front: each character fades in on a straight ramp, 0.02 s after the one before.
    @Test func aSweepIsASoftLinearFront() throws {
        let layer = try Self.layer(#"{"id": "s", "content": {"text": {"text": "Architect", "size": 63}}, "moves": [{"move": "sweep", "start": 0.5}]}"#)
        let reveal = try #require(MoveExpansion.effect(of: layer.moves[0], in: MoveContext(sceneDuration: 3, canvas: Self.canvas, layer: layer)).reveal)
        #expect(reveal.style == .sweep && abs(reveal.stagger - MoveExpansion.sweepStagger) < 1e-9 && reveal.partDuration == MoveExpansion.sweepFront)
        #expect(abs(reveal.fraction(ofPart: 2, at: reveal.start(ofPart: 2) + MoveExpansion.sweepFront / 2) - 0.5) < 1e-9)
    }

    /// A blink: off before it, then on and off a frame at a time, on from the fourth frame as it eases 12 px along.
    @Test func aBlinkFlickersAFrameAtATime() throws {
        let effect = MoveExpansion.effect(of: MotionMove(.blink, start: 1), in: MoveContext(sceneDuration: 3, canvas: Self.canvas))
        let opacity = try #require(effect.tracks[.opacity]?.first)
        let frame = MoveExpansion.blinkFrame
        #expect([0.99, 1, 1 + frame, 1 + 2 * frame, 1 + 3 * frame, 1 + 4 * frame].map { opacity.value(at: $0 + 1e-4) } == [0, 1, 0, 1, 0, 1])
        let slide = try #require(effect.tracks[.positionX]?.first)
        #expect(abs(slide.value(at: 1 + 4 * frame) + MoveExpansion.blinkTravel) < 0.01 && slide.value(at: 2) == 0, "\(slide.value(at: 1 + 4 * frame))")
    }

    /// A card grows past the frame from its middle, its corners to 27 px; a fill changing shape stays a fill.
    @Test func aCardGrowsToCoverTheFrame() throws {
        let card = ShapeContent(size: CGSize(width: 1152, height: 763), cornerRadius: 11.5, color: RGBAColor(red: 1, green: 1, blue: 1, alpha: 1))
        var context = MoveContext(sceneDuration: 3, canvas: Self.canvas)
        context.position = CGPoint(x: 960, y: 540)
        let morph = try #require(ShapeMorph(card, moves: [MotionMove(.grow, start: 0)], context: context))
        let grown = morph.state(at: MoveExpansion.growDuration)
        #expect(grown.size.width > Self.canvas.width && grown.size.height > Self.canvas.height && grown.radius == MoveExpansion.growRadius)
        // The film's box 0.1 s in was 1588 px wide (its left edge 384 → 166 px from 54.183 to 54.283)
        #expect(abs(morph.state(at: 0.1).size.width - 1588) < 120, "\(morph.state(at: 0.1).size.width)")

        var sweep = MotionMove(.morph, start: 0, duration: 0.3)
        sweep.size = CGSize(width: 1500, height: 700)
        let fill = ShapeContent(size: CGSize(width: 120, height: 700), cornerRadius: 40, color: RGBAColor(red: 1, green: 1, blue: 1, alpha: 1))
        #expect(try #require(ShapeMorph(fill, moves: [sweep], context: context)).state(at: 0.1).stroke == 0)
    }

    /// The mark alone where the whole line's middle ends, 1.125× its size; the name typed before the line slides; the tagline
    /// swept in 0.93 s in; the line where the document laid it once settled.
    @Test func theWordmarkOpensOutOfItsMark() throws {
        let group = try Self.layer(#"""
            {"id": "lockup", "content": {"group": [
              {"id": "mark", "content": {"text": {"text": "II", "size": 63, "weight": "bold"}}, "transform": {"position": [-339, 0, 0], "anchor": [0, 0.5]}},
              {"id": "eleven", "content": {"text": {"text": "Eleven", "size": 63, "weight": "bold"}}, "transform": {"position": [-306, 0, 0], "anchor": [0, 0.5]}},
              {"id": "agents", "content": {"text": {"text": "Agents", "size": 63, "weight": "regular"}}, "transform": {"position": [-108, 0, 0], "anchor": [0, 0.5]}},
              {"id": "architect", "content": {"text": {"text": "Architect", "size": 63, "weight": "regular"}}, "transform": {"position": [112, 0, 0], "anchor": [0, 0.5]}}
            ]}, "transform": {"position": [951, 542, 0]}, "moves": [{"move": "unfold", "start": 0.1}]}
            """#)
        let unfolded = DocumentExpansion.unfolded(group, sizes: [:], context: MoveContext(sceneDuration: 3, canvas: Self.canvas))
        guard case .group(let children) = unfolded.content, case .group(let laid) = group.content else { Issue.record("no group"); return }
        let widths = laid.map { layer -> Double in
            guard case .text(let text) = layer.content else { return 0 }
            return TextImage(text, scale: 0).size.width
        }
        let whole = (laid[0].transform.position.x + laid[3].transform.position.x + widths[3]) / 2
        let value = { (layer: MotionLayer, property: MotionProperty, time: Double) in
            layer.keyframes[property].flatMap { PropertyTrack(property, keyframes: $0) }?.value(at: time) ?? 0
        }
        // At its start the mark's middle is where the whole line's middle ends
        let markMiddle = value(unfolded, .positionX, 0.1) + MoveExpansion.unfoldScale * (value(children[0], .positionX, 0.1) + widths[0] / 2)
        #expect(abs(markMiddle - (951 + whole)) < 1, "\(markMiddle) \(951 + whole)")
        #expect(abs(value(unfolded, .scale, 0.1) - MoveExpansion.unfoldScale) < 1e-6)
        // Settled where it was laid out
        #expect(value(unfolded, .positionX, 3) == 951 && abs(value(unfolded, .scale, 3) - 1) < 1e-6 && value(children[0], .positionX, 3) == -339)
        let context = MoveContext(sceneDuration: 3, canvas: Self.canvas)
        let typed = children[1...2].map { MoveExpansion.timing(of: $0.moves[0], in: context) }
        #expect(children[1].moves[0].kind == .type && abs(typed[0].start - 0.47) < 1e-9 && typed[1].start + typed[1].duration <= 0.1 + 0.58 + 1e-9)
        #expect(children[3].moves[0].kind == .sweep && children[3].moves[0].start == 0.1 + MoveExpansion.unfoldTagline)
    }

    /// The dark beat's 12 stars on a circle a third of the frame's height across from the middle, turning clockwise, opening
    /// out as they go; the sphere's dots born outwards and gone from the inside out.
    @Test func starsTurnAndDotsAreBornOutwards() throws {
        let box = try Self.layer(##"""
            {"id": "box", "content": {"shape": {"size": [520, 84], "color": "#1f2433"}}, "transform": {"position": [960, 540, 0]},
             "moves": [{"move": "orbit", "start": 0.2}, {"move": "dots", "start": 0.2}]}
            """##)
        let accents = BurstExpansion.accents(of: .init(layer: box, style: StyleTokens(), sizes: [:], context: MoveContext(sceneDuration: 3, canvas: Self.canvas)))
        let (orbit, dots) = (accents.behind[0], accents.behind[1])
        #expect(BurstExpansion.isParticles(orbit.id) && BurstExpansion.isParticles(dots.id))
        guard case .group(let stars) = orbit.content, case .group(let squares) = dots.content else { Issue.record("no groups"); return }
        #expect(stars.count == 12)
        let place = { (layer: MotionLayer, time: Double) in
            CGPoint(x: layer.keyframes[.positionX].flatMap { PropertyTrack(.positionX, keyframes: $0) }?.value(at: time) ?? layer.transform.position.x,
                    y: layer.keyframes[.positionY].flatMap { PropertyTrack(.positionY, keyframes: $0) }?.value(at: time) ?? layer.transform.position.y)
        }
        let (early, later) = (place(stars[0], 0.2), place(stars[0], 0.4))
        #expect(abs(hypot(early.x, early.y) - 0.363 * 1080) < 1)
        // Clockwise on screen (y down): from the top towards the right
        #expect(later.x > early.x && atan2(later.y, later.x) > atan2(early.y, early.x))
        #expect(abs(hypot(place(stars[0], 1.6).x, place(stars[0], 1.6).y) - 0.418 * 1080) < 1)

        #expect((25...70).contains(squares.count), "\(squares.count)")
        let distance = { (layer: MotionLayer) in hypot(layer.transform.position.x, layer.transform.position.y) }
        let born = { (layer: MotionLayer) in layer.keyframes[.opacity]?.first { $0.value == 1 }?.time ?? 0 }
        let inner = try #require(squares.min { distance($0) < distance($1) })
        let outer = try #require(squares.max { distance($0) < distance($1) })
        #expect(born(inner) < born(outer))
        #expect((inner.keyframes[.opacity]?.last?.time ?? 0) < (outer.keyframes[.opacity]?.last?.time ?? 0))
    }

    /// Marks lie under the layer they frame and over what's before it: white squares on a dark ground, 42 px outside the box;
    /// and the film is drawn sharp.
    @Test func marksFrameTheirLayer() async throws {
        let json = #"""
            {"version": 1, "canvas": {"size": [1920, 1080], "background": "#f3f2f0"}, "scenes": [{"id": "one", "duration": 2, "field": "paper", "layers": [
              {"id": "ground", "content": {"shape": {"size": [1920, 1080], "color": "#171717"}}, "transform": {"position": [960, 540, 0]}},
              {"id": "box", "content": {"shape": {"size": [400, 200], "color": "#1f2433"}},
               "transform": {"position": [960, 540, 0]}, "moves": [{"move": "marks", "color": "#ffffff"}]}
            ]}]}
            """#
        let plan = await MotionPlan.build(try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8)), bundle: URL.temporaryDirectory, shorterSide: 270)
        #expect(plan.isEditorial)
        let frame = MotionFrameRenderer.image(at: 1, plan: plan)
        // The top-left square: (760 − 42, 440 − 42) on the canvas, a quarter of it here, from the bottom left
        #expect(try Self.color(of: frame, at: CGPoint(x: 180, y: 171)).allSatisfy { $0 > 200 })
        #expect(try Self.color(of: frame, at: CGPoint(x: 120, y: 60)).allSatisfy { $0 < 40 })
    }

    /// The wipe: the next scene comes in from the right behind a soft front, speeding up.
    @Test func aWipeComesInFromTheRight() throws {
        let size = CGSize(width: 240, height: 135)
        let (red, blue) = (CIImage(color: CIColor(red: 1, green: 0, blue: 0)), CIImage(color: CIColor(red: 0, green: 0, blue: 1)))
        let frame = CGRect(origin: .zero, size: size)
        let half = MotionFrameRenderer.wiped(red.cropped(to: frame), into: blue.cropped(to: frame), progress: 0.5, size: size)
        let (left, right) = (try Self.color(of: half, at: CGPoint(x: 2, y: 60)), try Self.color(of: half, at: CGPoint(x: 237, y: 60)))
        #expect(left[0] > left[2] && right[2] > right[0], "\(left) \(right)")
        let transition = SeamExpansion.Transition(seam: .wipe, duration: SeamExpansion.wipeDuration)
        #expect(transition.progress(at: SeamExpansion.wipeDuration / 2) < 0.4)
    }

    /// In an editorial film, mono labels are texture (size, contrast and reading time aren't held to the rules) and a cut
    /// between plain paper and the editorial grounds keeps the look; other text is still read.
    @Test func theLintReadsAnEditorialFilmAsTheFilmIs() throws {
        let json = #"""
            {"version": 1, "canvas": {"size": [1920, 1080], "frameRate": 60, "background": "#f3f2f0"}, "scenes": [
              {"id": "one", "duration": 2, "field": "paper", "layers": [
                {"id": "label", "content": {"text": {"text": "WRITING FIX", "size": 14, "face": "mono", "color": "#858483"}},
                 "transform": {"position": [400, 300, 0]}, "moves": [{"move": "blink", "start": 0.1}]}
              ]},
              {"id": "two", "duration": 2, "field": "plain", "layers": [
                {"id": "small", "content": {"text": {"text": "Small words", "size": 14, "color": "#1b1a19"}},
                 "transform": {"position": [960, 540, 0]}, "moves": [{"move": "blink", "start": 0.1}]}
              ]},
              {"id": "three", "duration": 2, "field": "ink", "layers": [
                {"id": "line", "content": {"text": {"text": "to the standards", "size": 92, "color": "#f9fafb"}},
                 "transform": {"position": [960, 540, 0]}, "moves": [{"move": "brighten", "start": 0}]}
              ]}
            ]}
            """#
        let findings = MotionLint.findings(in: try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8)))
        #expect(!findings.contains { $0.layer == "label" }, "\(findings.map(\.message))")
        #expect(findings.contains { $0.layer == "small" && $0.rule == .textSize })
        #expect(!findings.contains { $0.rule == .look || $0.rule == .firstMove }, "\(findings.map(\.message))")
    }

    /// The score ticks on a blink and rises into a card filling the frame.
    @Test func blinksTickAndGrowsRise() async throws {
        let json = #"""
            {"version": 1, "canvas": {"size": [1920, 1080], "frameRate": 60, "background": "#f3f2f0"}, "sound": {"style": "editorial"}, "scenes": [
              {"id": "one", "duration": 3, "field": "paper", "layers": [
                {"id": "label", "content": {"text": {"text": "WRITING FIX", "size": 14, "face": "mono"}},
                 "transform": {"position": [400, 300, 0]}, "moves": [{"move": "blink", "start": 0.5}]},
                {"id": "card", "content": {"shape": {"size": [1152, 763], "color": "#868d9e", "picture": "dusk"}},
                 "transform": {"position": [960, 540, 0]}, "moves": [{"move": "grow", "start": 1.5}]}
              ]}
            ]}
            """#
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8))
        let sheet = SoundCueSheet.make(plan: await MotionPlan.build(document, bundle: URL.temporaryDirectory), document: document)
        #expect(sheet.cues.contains { if case .tick = $0.voice { abs($0.time - 0.5) < 0.02 } else { false } })
        #expect(sheet.cues.contains { if case .riser = $0.voice { abs($0.time - 1.5 - MoveExpansion.growDuration) < 0.02 } else { false } })
    }

    private static func layer(_ json: String) throws -> MotionLayer {
        try JSONDecoder().decode(MotionLayer.self, from: Data(json.utf8))
    }

    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    /// The RGB bytes of the pixel at `point` (Core Image's coordinates, from the bottom left).
    private static func color(of image: CIImage, at point: CGPoint) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        context.render(image, toBitmap: &bytes, rowBytes: 4, bounds: CGRect(origin: point, size: CGSize(width: 1, height: 1)), format: .RGBA8, colorSpace: nil)
        return Array(bytes.prefix(3))
    }
}
