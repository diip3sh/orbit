//
//  SeamLanguageTests.swift
//  RecoTests
//

import CoreImage
import Foundation
import Testing
@testable import Reco

/// Seams drawn in a field's language (glow, dither, ring) and the one-look rule (spec 0012, looks).
struct SeamLanguageTests {

    // MARK: - Plans

    /// A seam takes the next scene's field when it's of its family, else the family's first pick, coloured
    /// from the brand.
    @Test func aSeamSpeaksTheNextScenesField() async throws {
        let json = #"""
            {"version": 1, "canvas": {"field": "orb"}, "style": {"accent": "#3ecf8e"},
             "scenes": [{"id": "one", "duration": 2}, {"id": "two", "duration": 2, "seam": "glow"},
                        {"id": "three", "duration": 2, "seam": "dither"}, {"id": "four", "duration": 2, "seam": "ring", "field": "warp"}]}
            """#
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8))
        let plan = await MotionPlan.build(document, bundle: URL.temporaryDirectory)
        let transitions = plan.scenes.map(\.transition)

        #expect(transitions[0] == nil)
        #expect(transitions[1]?.look == .orb && transitions[1]?.duration == SeamExpansion.glowDuration)
        #expect(transitions[1]?.palette == FieldPalette(.orb, accent: document.style.accent, background: document.canvas.background))
        #expect(transitions[2]?.look == .matrix)
        #expect(transitions[3]?.look == .halo)
        #expect(plan.scenes[2].overlap == SeamExpansion.ringDuration)
    }

    /// Dither steps on at 15 frames a second; light and smoke burst out and settle.
    @Test func ditherStepsAndTheOthersEase() {
        let dither = SeamExpansion.Transition(seam: .dither, duration: SeamExpansion.ditherDuration)
        #expect(dither.progress(at: 0.05) == 0)
        #expect(dither.progress(at: 0.07) == dither.progress(at: 0.1))
        #expect(abs(dither.progress(at: 0.41) - 6.0 / 12) < 1e-9)
        #expect(dither.progress(at: SeamExpansion.ditherDuration) == 1)

        let glow = SeamExpansion.Transition(seam: .glow, duration: SeamExpansion.glowDuration)
        #expect(glow.progress(at: 0.1) > 2 * 0.1 / SeamExpansion.glowDuration)
        let ring = SeamExpansion.Transition(seam: .ring, duration: SeamExpansion.ringDuration)
        #expect(ring.progress(at: 0.1) > 2 * 0.1 / SeamExpansion.ringDuration)
        #expect(glow.progress(at: SeamExpansion.glowDuration) == 1)
    }

    // MARK: - Drawing

    /// Each seam starts on the scene before and ends on the next, and is neither half-way.
    @Test(arguments: [MotionSeam.glow, .dither, .ring])
    func drawsFromTheSceneBeforeToTheNext(seam: MotionSeam) throws {
        let size = CGSize(width: 240, height: 135)
        let extent = CGRect(origin: .zero, size: size)
        let outgoing = CIImage(color: CIColor(red: 0.8, green: 0.1, blue: 0.1)).cropped(to: extent)
        let incoming = CIImage(color: CIColor(red: 0.1, green: 0.1, blue: 0.8)).cropped(to: extent)
        var transition = SeamExpansion.Transition(seam: seam, duration: 1)
        transition.look = MotionField.allCases.first { $0.family == seam.family } ?? .plain
        transition.palette = FieldPalette(transition.look, accent: RGBAColor(hex: "#3ecf8e"), background: RGBAColor(red: 0, green: 0, blue: 0, alpha: 1))
        let draw = { (progress: Double) in
            try Self.bytes(of: FieldRenderer.seam(transition, between: (outgoing, incoming), progress: progress, at: 2, size: size))
        }

        let (before, after, middle) = (try Self.bytes(of: outgoing), try Self.bytes(of: incoming), try draw(0.5))
        #expect(Self.most(try draw(0), before) <= 1)
        #expect(Self.most(try draw(1), after) <= 1)
        #expect(Self.most(middle, before) > 40 && Self.most(middle, after) > 40)
    }

    // MARK: - Lint

    /// One look a film, and a seam only into a scene of its language; the halo and plain go with any.
    @Test func keepsAFilmToOneLook() throws {
        let json = #"""
            {"version": 1, "canvas": {"field": "ember"},
             "scenes": [{"id": "one", "duration": 3}, {"id": "two", "duration": 3, "seam": "glow", "field": "bloom"},
                        {"id": "three", "duration": 3, "seam": "dither", "field": "sunlit"}, {"id": "four", "duration": 3, "seam": "whip", "field": "matrix"},
                        {"id": "five", "duration": 3, "seam": "ring", "field": "halo"}]}
            """#
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8))
        let findings = MotionLint.findings(in: document).filter { $0.rule == .look }

        #expect(findings.map(\.scene) == ["three", "four"])
    }

    /// A cut keeps the ground; a whip or the look's seam changes it.
    @Test func aCutKeepsTheGround() throws {
        let json = #"""
            {"version": 1, "canvas": {"field": "bloom"},
             "scenes": [{"id": "bar", "duration": 3}, {"id": "typed", "duration": 3, "field": "ember"},
                        {"id": "closer", "duration": 3, "field": "ember"}, {"id": "page", "duration": 3, "seam": "glow", "field": "sunlit"},
                        {"id": "code", "duration": 3, "seam": "whip", "field": "ripple"}]}
            """#
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8))

        #expect(MotionLint.findings(in: document).filter { $0.rule == .look }.map(\.scene) == ["typed"])
    }

    /// A light or dither film's opening control arrives in its look's seam, and its typing waits for it;
    /// satin's cuts in.
    @Test(arguments: [(MotionField.bloom, MotionSeam?.some(.glow)), (.matrix, .dither), (.satin, nil)])
    func anOpeningArrivesInItsLook(field: MotionField, seam: MotionSeam?) async throws {
        let json = """
            {"version": 1, "canvas": {"field": "\(field.rawValue)"}, "style": {"accent": "#1488fc"},
             "assets": [{"id": "bar", "url": "https://example.com", "selector": "div", "glass": true, "typing": {"field": "p", "text": "hi"}}],
             "scenes": [{"id": "bar", "duration": 4, "shot": {"shot": "macro", "ui": "bar"}}]}
            """
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8))
        let plan = await MotionPlan.build(document, bundle: URL.temporaryDirectory)

        #expect(plan.scenes[0].arrival?.seam == seam)
        let arrives = ShotLayout.macroBreath + (plan.scenes[0].arrival?.duration ?? 0)
        let layer = try #require(DocumentExpansion.expanded(document, sizes: ["bar": CGSize(width: 600, height: 50)]).scenes[0].layers.first)
        guard case .lifted(let content) = layer.content else { Issue.record("not a ui layer"); return }
        #expect(content.typingStart == arrives + ShotLayout.macroTypingDelay)
    }

    /// Paper's looks compete with type over them, not with a macro's glass.
    @Test func aBusyFieldBelongsUnderGlass() throws {
        let json = #"""
            {"version": 1, "canvas": {"field": "warp"},
             "assets": [{"id": "bar", "url": "https://example.com", "selector": "input", "glass": true}],
             "scenes": [{"id": "macro", "duration": 3, "shot": {"shot": "macro", "ui": "bar"}},
                        {"id": "title", "duration": 3, "shot": {"shot": "title", "text": "Ship faster"}}]}
            """#
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8))
        let findings = MotionLint.findings(in: document)

        #expect(findings.filter { $0.rule == .busyField }.map(\.scene) == ["title"])
        #expect(!findings.contains { $0.rule == .material })

        // Page text bare over the dither: its light runs through the letters
        var bare = document
        bare.assets[0].glass = nil
        bare.assets[0].bare = true
        #expect(MotionLint.findings(in: bare).filter { $0.rule == .material }.map(\.scene) == ["macro"])
    }

    // MARK: - Helpers

    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    /// The largest difference between two images' bytes.
    private static func most(_ one: [UInt8], _ other: [UInt8]) -> Int {
        zip(one, other).map { abs(Int($0) - Int($1)) }.max() ?? 0
    }

    private static func bytes(of image: CIImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 240 * 135 * 4)
        context.render(image, toBitmap: &bytes, rowBytes: 240 * 4, bounds: CGRect(x: 0, y: 0, width: 240, height: 135), format: .RGBA8, colorSpace: nil)
        return bytes
    }
}
