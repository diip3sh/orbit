//
//  MotionDesignTests.swift
//  RecoTests
//

import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import Reco

/// Motion design (spec 0014): a shape morphs from where the last change left it and floods past the frame; pops
/// and presses settle back to size; letters overshoot and kinetic type keeps its pace; particles and rings sit beside
/// their layer; a list's rows build as its scroll brings them in; a pointer lands on what it clicks; each has its sound.
struct MotionDesignTests {

    private let bundle = URL.temporaryDirectory

    private func document(_ layers: String, duration: Double = 4, field: MotionField = .plain) throws -> MotionDocument {
        var document = MotionDocument(scenes: [MotionScene(
            id: "scene", duration: duration, layers: try JSONDecoder().decode([MotionLayer].self, from: Data(layers.utf8))
        )])
        document.canvas.frameRate = 30
        document.canvas.field = field
        document.canvas.background = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
        document.style.accent = RGBAColor(hex: "#1ed760")
        return document
    }

    private func pill(_ moves: String, at position: String = "[960, 540, 0]", color: String = "1ed760") -> String {
        #"[{"id": "pill", "content": {"shape": {"size": [40, 40], "cornerRadius": 20, "color": "\#(color)"}}, "transform": {"position": \#(position)}, "moves": \#(moves)}]"#
    }

    // MARK: - Morphs

    @Test func aMorphStartsWhereTheLastLeftIt() async throws {
        let moves = #"[{"move": "morph", "start": 0.5, "size": [560, 184]}, {"move": "morph", "start": 1.5, "stroke": 3},"#
            + #" {"move": "morph", "start": 2.5, "size": [16, 130], "radius": 5}]"#
        let plan = await MotionPlan.build(try document(pill(moves)), bundle: bundle)
        let morph = try #require(plan.scenes[0].layers[0].morph)

        #expect(morph.state(at: 0.4).size == CGSize(width: 40, height: 40))
        let growing = morph.state(at: 0.7)
        #expect(growing.size.width > 40 && growing.size.width < 560)
        // A pill stays a pill as it grows
        #expect(abs(growing.radius - growing.size.height / 2) < 1e-9)
        #expect(morph.state(at: 1.2) == ShapeMorph.State(size: CGSize(width: 560, height: 184), radius: 92, color: morph.base.color, stroke: 0))
        // The fill thins into an outline, then holds it
        let thinning = morph.state(at: 1.7)
        #expect(thinning.stroke > 3 && thinning.stroke < 92)
        #expect(morph.state(at: 2.2).stroke == 3)
        let caret = morph.state(at: 3.5)
        #expect(caret.size == CGSize(width: 16, height: 130) && caret.radius == 5 && caret.stroke == 3)
    }

    @Test func aMorphsPlacesChain() async throws {
        let moves = #"[{"move": "morph", "start": 0.2, "to": [960, 540]}, {"move": "morph", "start": 1, "to": [400, 540]}]"#
        let plan = await MotionPlan.build(try document(pill(moves, at: "[960, 900, 0]")), bundle: bundle)
        let layer = plan.scenes[0].layers[0]

        #expect(layer.value(.positionY, at: 0) == 900)
        #expect(abs(layer.value(.positionY, at: 0.9) - 540) < 1e-9)
        #expect(layer.value(.positionX, at: 0.9) == 960)
        #expect(abs(layer.value(.positionX, at: 2) - 400) < 1e-9)
        // A morph that only moves the layer leaves its shape alone
        #expect(layer.morph == nil)
    }

    @Test func aFloodCoversTheFrameFromItsCorner() async throws {
        let plan = await MotionPlan.build(try document(pill(#"[{"move": "flood", "start": 0.5}]"#, at: "[0, 0, 0]")), bundle: bundle)
        let morph = try #require(plan.scenes[0].layers[0].morph)

        // Its dip first, to 0.6 of its size
        let dipped = morph.state(at: 0.5 + ShapeMorph.floodDip)
        #expect(abs(dipped.size.width - 24) < 1e-6)
        let filled = morph.state(at: 2)
        #expect(filled.stroke == 0 && filled.isRound)
        // The frame's far corner is inside its round end
        let inner = CGPoint(x: filled.size.width / 2 - filled.radius, y: filled.size.height / 2 - filled.radius)
        #expect(hypot(max(1920 - inner.x, 0), max(1080 - inner.y, 0)) <= filled.radius)
    }

    @Test func aFillComingFromClearKeepsItsColour() async throws {
        let moves = #"[{"move": "morph", "start": 0, "duration": 1, "color": "1ed760"}]"#
        let plan = await MotionPlan.build(try document(pill(moves, color: "1ed76000")), bundle: bundle)
        let middle = try #require(plan.scenes[0].layers[0].morph).state(at: 0.5).color

        let green = try #require(RGBAColor(hex: "#1ed760"))
        #expect(abs(middle.green - green.green) < 1e-9 && abs(middle.red - green.red) < 1e-9)
        #expect(middle.alpha > 0 && middle.alpha < 1)
    }

    @Test func aMorphingPillIsDrawnAtItsSize() async throws {
        let moves = #"[{"move": "morph", "start": 0, "duration": 0.5, "size": [560, 184]}]"#
        let plan = await MotionPlan.build(try document(pill(moves)), bundle: bundle, shorterSide: 270, frameRate: 30)
        let box = try Self.box(of: MotionFrameRenderer.image(at: 1, plan: plan), size: plan.outputSize) { $0[1] > 128 }

        // 560×184 at a quarter of the canvas
        #expect(abs(box.width - 140) <= 2 && abs(box.height - 46) <= 2)
    }

    // MARK: - Pops, presses, letters, kinetic type

    @Test func popsAndPressesSettleBackToSize() async throws {
        let moves = #"[{"move": "pop", "start": 0.1}, {"move": "press", "start": 1}]"#
        let plan = await MotionPlan.build(try document(pill(moves)), bundle: bundle)
        let layer = plan.scenes[0].layers[0]

        #expect(abs(layer.value(.scale, at: 0.1) - MoveExpansion.popFrom) < 1e-9)
        #expect(layer.value(.scale, at: 0.35) > 1)
        #expect(abs(layer.value(.scale, at: 0.6) - 1) < 1e-9)
        #expect(abs(layer.value(.scale, at: 1.1) - MoveExpansion.pressDepth) < 1e-9)
        #expect(abs(layer.value(.scale, at: 1.5) - 1) < 1e-9)
    }

    @Test func lettersOvershootAndKineticTypeKeepsItsPace() async throws {
        let layers = #"[{"id": "start", "content": {"text": {"text": "Start", "size": 64}}, "moves": [{"move": "letters", "start": 0.1}]},"#
            + #" {"id": "song", "content": {"text": {"text": "Patient Zero", "size": 150}}, "moves": [{"move": "kinetic", "start": 0.5}]}]"#
        let plan = await MotionPlan.build(try document(layers), bundle: bundle)
        let letters = try #require(plan.scenes[0].layers[0].reveal)
        let kinetic = try #require(plan.scenes[0].layers[1].reveal)

        #expect(letters.style == .letter && abs(letters.stagger - MoveExpansion.letterStagger) < 1e-12)
        #expect(letters.progress(ofPart: 0, at: 0.1 + 0.6 * MoveExpansion.letterDuration) > 1)
        #expect(letters.fraction(ofPart: 0, at: 0.1 + MoveExpansion.letterDuration) == 1)
        #expect(kinetic.style == .kinetic)
        #expect(abs(kinetic.start(ofPart: 11) - (0.5 + 11 / MoveExpansion.kineticRate)) < 1e-9)
        #expect(plan.scenes[0].layers[1].accent == RGBAColor(hex: "#1ed760"))
    }

    // MARK: - Bursts, ripples, scrolls

    @Test func aBurstThrowsTheSameParticlesFromBehindItsLayerInItsColourThen() throws {
        let moves = #"[{"move": "morph", "start": 0.9, "color": "1ed760"}, {"move": "burst", "start": 1}]"#
        let document = try document(pill(moves, color: "ffffff26"))
        let layers = DocumentExpansion.expanded(document, sizes: [:]).scenes[0].layers

        #expect(layers.map(\.id) == ["pill.burst1", "pill"])
        guard case .group(let particles) = layers[0].content, case .shape(let particle) = particles.first?.content else {
            Issue.record("No particles")
            return
        }
        #expect(particles.count == BurstExpansion.particles && particle.kind == .triangle)
        // The disc's green as it bursts, not the faint white it was
        #expect(particle.color.green == RGBAColor(hex: "#1ed760")?.green)
        #expect(DocumentExpansion.expanded(document, sizes: [:]).scenes[0].layers == layers)
        let track = try #require(PropertyTrack(.positionX, keyframes: particles[0].keyframes[.positionX] ?? []))
        #expect(track.value(at: 1) == 0 && track.value(at: 3) != 0)
    }

    @Test func aRippleOpensSoftBandsOverItsLayer() throws {
        let layers = DocumentExpansion.expanded(try document(pill(#"[{"move": "ripple", "start": 1, "stroke": 80}]"#)), sizes: [:]).scenes[0].layers

        #expect(layers.map(\.id) == ["pill", "pill.ripple0"])
        guard case .group(let rings) = layers[1].content, case .shape(let ring) = rings.first?.content else {
            Issue.record("No rings")
            return
        }
        #expect(rings.count == BurstExpansion.rings && ring.stroke == 80 && rings[0].blur == 80 * BurstExpansion.softBands)
        #expect(rings[1].moves.first?.start == 1 + BurstExpansion.ringStagger)
    }

    @Test func rowsBuildAsTheScrollBringsThemIn() throws {
        let rows = (0..<5).map { #"{"id": "r\#($0)", "content": {"shape": {"size": [100, 100], "color": "ffffff"}}, "transform": {"position": [0, \#($0 * 300), 0]}}"# }
        let list = #"[{"id": "list", "content": {"group": [\#(rows.joined(separator: ", "))]}, "transform": {"position": [960, 400, 0]},"#
            + #" "moves": [{"move": "cascade", "start": 0.1}, {"move": "scroll", "start": 0.5, "to": [960, -600]}]}]"#
        let expanded = DocumentExpansion.expanded(try document(list), sizes: [:]).scenes[0].layers[0]
        guard case .group(let built) = expanded.content else {
            Issue.record("No rows")
            return
        }
        let starts = built.compactMap { $0.moves.first { $0.kind == .rise }?.start }

        // Rows in the frame come in at once; the one below waits for the scroll to bring it up
        #expect(starts.count == 5 && starts[0] < 0.2 && starts[2] < 0.5)
        #expect(starts[3] > 0.5 && starts[4] > starts[3])
    }

    // MARK: - Clicks, shapes, the field

    @Test func aClickPutsThePointerOnItsLayer() async throws {
        let plan = await MotionPlan.build(try document(pill(#"[{"move": "click", "start": 1}]"#)), bundle: bundle)
        let pointer = try #require(plan.pointer)
        let layer = plan.scenes[0].layers[0]

        #expect(layer.clicks == [MotionPlan.Click(press: 1, leaves: 1.8)])
        let corners = try #require(plan.placements(of: plan.scenes[0], at: 1).first).corners
        #expect(pointer.image(of: layer.clicks[0], on: corners, at: 0.2, canvas: plan.canvas, outputScale: 1) == nil)
        let hand = try #require(pointer.image(of: layer.clicks[0], on: corners, at: 1, canvas: plan.canvas, outputScale: 1))
        // Its tip just under the pill's middle, the hand about 8 % of the frame tall
        #expect(abs(hand.extent.midX - 960) < 60 && hand.extent.height > 60)
    }

    @Test func outlinesAndGlyphsDraw() throws {
        let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
        let outline = ShapeMorph.image(of: ShapeMorph.State(size: CGSize(width: 100, height: 40), radius: 20, color: white, stroke: 3), scale: 1)
        let pixels = try Self.pixels(of: outline, size: CGSize(width: 100, height: 40))
        // Drawn over its first three rows, clear inside
        #expect((0..<3).allSatisfy { pixels[($0 * 100 + 50) * 4 + 3] > 200 })
        #expect(pixels[(5 * 100 + 50) * 4 + 3] < 30 && pixels[(20 * 100 + 50) * 4 + 3] == 0)
        let check = try #require(ShapeGlyph.image(of: ShapeContent(kind: .check, size: CGSize(width: 50, height: 50), color: white), scale: 2))
        #expect(check.extent.size == CGSize(width: 100, height: 100))
        #expect(try Self.pixels(of: check, size: check.extent.size).enumerated().contains { $0.offset % 4 == 3 && $0.element > 200 })
    }

    @Test func theFieldCanBeTonedDown() async throws {
        var video = try document(pill("[]"), field: .ember)
        let full = await MotionPlan.build(video, bundle: bundle, shorterSide: 108, frameRate: 30)
        video.canvas.fieldStrength = 0.4
        let toned = await MotionPlan.build(video, bundle: bundle, shorterSide: 108, frameRate: 30)
        let brightness = { (plan: MotionPlan) in
            try Self.pixels(of: MotionFrameRenderer.image(at: 2, plan: plan), size: plan.outputSize).enumerated()
                .filter { $0.offset % 4 == 1 }.map { Double($0.element) }.reduce(0, +)
        }
        let ratio = try brightness(toned) / brightness(full)
        #expect(ratio > 0.3 && ratio < 0.55)

        video.canvas.fieldStrength = 1.5
        #expect(throws: MotionDocumentError.self) { try video.validate() }
        #expect(try JSONDecoder().decode(MotionCanvas.self, from: Data("{}".utf8)).fieldStrength == 1)
    }

    @Test func movesSayWhatTheyNeed() {
        let text = LayerContent.text(TextContent(text: "Hi"))
        let shape = LayerContent.shape(ShapeContent(size: CGSize(width: 10, height: 10), color: RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)))
        let glyph = LayerContent.shape(ShapeContent(kind: .plus, size: CGSize(width: 10, height: 10), color: RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)))
        var morph = MotionMove(.morph)
        #expect(morph.problem(on: shape) != nil)
        morph.size = CGSize(width: 20, height: 20)
        #expect(morph.problem(on: shape) == nil && morph.problem(on: text) != nil && morph.problem(on: glyph) != nil)
        morph.size = nil
        morph.target = CGPoint(x: 1, y: 1)
        #expect(morph.problem(on: text) == nil)
        #expect(MotionMove(.flood).problem(on: text) != nil && MotionMove(.flood).problem(on: shape) == nil)
        #expect(MotionMove(.scroll).problem(on: shape) != nil)
        #expect(MotionMove(.letters).problem(on: shape) != nil && MotionMove(.kinetic).problem(on: text) == nil)
    }

    // MARK: - Sound

    @Test func eachEventHasItsSound() async throws {
        let layers = #"[{"id": "pill", "content": {"shape": {"size": [40, 40], "cornerRadius": 20, "color": "1ed760"}}, "transform": {"position": [960, 540, 0]},"#
            + #" "moves": [{"move": "pop", "start": 0.2}, {"move": "click", "start": 1}, {"move": "flood", "start": 1.5}, {"move": "burst", "start": 2.5}]},"#
            + #" {"id": "song", "content": {"text": {"text": "Hi you", "size": 100}}, "moves": [{"move": "kinetic", "start": 3}]},"#
            + #" {"id": "list", "content": {"group": []}, "transform": {"position": [960, 540, 0]},"#
            + #" "moves": [{"move": "scroll", "start": 0.5, "duration": 0.6, "to": [960, -1000]}]}]"#
        let plan = await MotionPlan.build(try document(layers, duration: 5), bundle: bundle)
        let cues = plan.sound.cues
        let frame = { SoundRules.frame($0, frameRate: 30) }
        let cued = { (time: Double, matches: (SoundCue.Voice) -> Bool) in cues.contains { matches($0.voice) && abs($0.time - frame(time)) < 1e-9 } }

        #expect(cued(0.2) { if case .blip = $0 { true } else { false } })
        #expect(cued(1) { if case .key(.letter) = $0 { true } else { false } })
        let filling = 1.5 + ShapeMorph.floodDip
        #expect(cued(filling) { if case .riser = $0 { true } else { false } })
        #expect(cued(filling + SoundRules.floodThump.after) { if case .thump = $0 { true } else { false } })
        #expect(cues.filter { if case .glass = $0.voice { abs($0.time - frame(2.5)) < 1e-9 } else { false } }.count == 2)
        // "Hi you": five letters and a space, at the letters' times
        #expect(cues.filter { if case .key = $0.voice { $0.time >= 3 } else { false } }.count == 6)
        #expect(cued(0.8) { if case .whoosh = $0 { true } else { false } })
    }

    // MARK: - Pixels

    private static func pixels(of image: CIImage, size: CGSize) throws -> [UInt8] {
        let width = Int(size.width.rounded()), height = Int(size.height.rounded())
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(image, toBitmap: &data, rowBytes: width * 4, bounds: CGRect(x: 0, y: 0, width: width, height: height), format: .RGBA8, colorSpace: nil)
        // Rows from the top
        return (0..<height).reversed().flatMap { row in data[(row * width * 4)..<((row + 1) * width * 4)] }
    }

    /// The box of the pixels `matches` picks, in pixels.
    private static func box(of image: CIImage, size: CGSize, _ matches: ([UInt8]) -> Bool) throws -> CGRect {
        let pixels = try pixels(of: image, size: size)
        let width = Int(size.width.rounded())
        var (minX, minY, maxX, maxY) = (Int.max, Int.max, Int.min, Int.min)
        for index in stride(from: 0, to: pixels.count, by: 4) where matches(Array(pixels[index..<(index + 4)])) {
            let (column, row) = ((index / 4) % width, (index / 4) / width)
            (minX, minY, maxX, maxY) = (min(minX, column), min(minY, row), max(maxX, column), max(maxY, row))
        }
        return minX <= maxX ? CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1) : .zero
    }
}
