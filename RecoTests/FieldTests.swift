//
//  FieldTests.swift
//  RecoTests
//

import CoreImage
import Foundation
import Testing
@testable import Reco

/// The fields behind a motion video's scenes (spec 0012, Q2): colours from the brand, the kernels,
/// and how documents name them.
struct FieldTests {

    // MARK: - Palette

    /// The gallery's own example palettes come back from their lead colour.
    @Test(arguments: [
        (MotionField.ember, "#ff3b2f", "#050405", ["#ff3b2f", "#8a1414", "#2a0c12"]),
        (MotionField.matrix, "#3ecf8e", "#060907", ["#2f9e6c"]),
        (MotionField.halo, "#3ecf8e", "#000000", ["#ffffff", "#3ecf8e"]),
        (MotionField.sunlit, "#c4730b", "#140c04", ["#c4730b", "#bdad5f", "#d8ccc7"])
    ])
    func coloursTheGallerysBrandsAsPicked(field: MotionField, accent: String, back: String, colors: [String]) throws {
        let palette = FieldPalette(field, accent: RGBAColor(hex: accent), background: Self.background)

        try Self.expect(palette.back, isNear: back)
        #expect(palette.colors.count == colors.count)
        for (color, hex) in zip(palette.colors, colors) {
            try Self.expect(color, isNear: hex)
        }
    }

    @Test func takesTheBrandsHueAtThePickedLightness() throws {
        let accent = try #require(RGBAColor(hex: "#3b82f6"))
        let lead = OKLCH(try #require(FieldPalette(.ember, accent: accent, background: Self.background).colors.first))

        #expect(abs(lead.hue - OKLCH(accent).hue) < 1)
        #expect(abs(lead.lightness - 0.654) < 0.005)
    }

    @Test(arguments: ["#e5e5e6", nil])
    func paintsABrandWithoutAHueInCoolGreys(accent: String?) {
        let palette = FieldPalette(.sunlit, accent: accent.flatMap(RGBAColor.init(hex:)), background: Self.background)

        for color in [palette.back] + palette.colors {
            #expect(OKLCH(color).chroma <= FieldPalette.neutralChroma + 0.002)
        }
    }

    /// Satin is monochrome, as New Raycast's ground is, whatever the brand.
    @Test(arguments: ["#3ecf8e", "#ff3b2f", nil])
    func keepsSatinMonochrome(accent: String?) throws {
        let palette = FieldPalette(.satin, accent: accent.flatMap(RGBAColor.init(hex:)), background: Self.background)

        try Self.expect(palette.back, isNear: "#000000")
        #expect(palette.colors.count == 1)
        try Self.expect(try #require(palette.colors.first), isNear: "#ffffff")
    }

    @Test func aPlainFieldIsTheBackground() {
        let palette = FieldPalette(.plain, accent: RGBAColor(hex: "#ff3b2f"), background: Self.background)

        #expect(palette.back == Self.background)
        #expect(palette.colors.isEmpty)
    }

    // MARK: - OKLCH

    @Test(arguments: ["#000000", "#ffffff", "#ff3b2f", "#2f9e6c", "#3b82f6", "#808080"])
    func oklchRoundTrips(hex: String) throws {
        let color = try #require(RGBAColor(hex: hex))
        try Self.expect(OKLCH(color).rgba, isNear: hex, tolerance: 0.5)
    }

    /// A colour outside sRGB loses chroma, not lightness or hue.
    @Test func fitsAColourIntoSRGBByItsChroma() {
        let fitted = OKLCH(OKLCH(lightness: 0.654, chroma: 0.4, hue: 265).rgba)

        #expect(abs(fitted.lightness - 0.654) < 0.002)
        #expect(abs(fitted.hue - 265) < 1)
        #expect(fitted.chroma < 0.4)
    }

    // MARK: - Kernels

    /// Each look is drawn by its kernel, as a pure function of its time.
    @Test(arguments: [MotionField.ember, .matrix, .halo, .sunlit, .satin])
    func drawsTheFieldOnItsOwnClock(field: MotionField) throws {
        let first = try Self.pixels(field, at: 2)

        // Textured, not the plain colour the renderer falls back to
        #expect(Self.spread(of: first) > 2, "\(field) looks flat")
        #expect(try Self.pixels(field, at: 2) == first)
        #expect(try Self.pixels(field, at: 6) != first)
    }

    // MARK: - Satin

    /// Satin stays as low key as the film the user approved: over a shot each setup's median is 0–6 of
    /// 255 there and its brightest folds under 75; only the wide shot's slab, a grey of 160, is brighter.
    @Test(arguments: SatinSetup.film.indices)
    func keepsSatinAsLowKeyAsTheFilm(setup: Int) throws {
        for time in stride(from: 0.0, through: 10, by: 2) {
            let green = try Self.pixels(.satin, at: time, shot: FieldRenderer.Shot(index: setup)).enumerated()
                .filter { $0.offset % 4 == 1 }.map(\.element).sorted()
            let median = green[green.count / 2]
            let top = green[green.count * 99 / 100]
            #expect(median <= 8, "setup \(setup) at \(time) s: median \(median)")
            #expect(top < (SatinSetup.film[setup].slab == nil ? 80 : 170), "setup \(setup) at \(time) s: 99th percentile \(top)")
        }
    }

    /// Each scene over satin takes the next of the film's setups on its own clock, so a shot opens as
    /// its setup does wherever it starts, and the fifth is lit as the first.
    @Test func lightsEachSatinShotAfresh() throws {
        let first = try Self.pixels(.satin, at: 1, shot: FieldRenderer.Shot(index: 0))

        #expect(try Self.pixels(.satin, at: 13, shot: FieldRenderer.Shot(index: 4, start: 12)) == first)
        #expect(try Self.pixels(.satin, at: 1, shot: FieldRenderer.Shot(index: 1)) != first)
    }

    /// The ground follows the camera at 15 % of its move: panned 100 px, it shows 15 px over.
    @Test func followsTheCameraAtAShareOfItsMove() throws {
        let still = try Self.pixels(.satin, at: 1)
        let panned = try Self.pixels(.satin, at: 1, shot: FieldRenderer.Shot(shift: CGVector(dx: 100, dy: 0)))

        var most = 0
        for row in 10..<125 {
            for column in 10..<200 {
                most = max(most, abs(Int(still[(row * 240 + column) * 4 + 1]) - Int(panned[(row * 240 + column + 15) * 4 + 1])))
            }
        }
        #expect(most <= 1)
    }

    /// The film's grain: 2.32 levels deep in the mid-tones (2.34 once rounded to 8 bits, as the film's
    /// frames measured), none in black, new each frame.
    @Test func grainsLikeTheFilm() throws {
        let extent = CGRect(x: 0, y: 0, width: 240, height: 135)
        let grey = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: extent)
        let grained = try Self.bytes(of: FieldRenderer.grained(grey, index: 7, size: extent.size))

        #expect(abs(Self.spread(of: grained) - 2.34) < 0.15)
        #expect(try Self.bytes(of: FieldRenderer.grained(grey, index: 7, size: extent.size)) == grained)
        #expect(try Self.bytes(of: FieldRenderer.grained(grey, index: 8, size: extent.size)) != grained)
        let black = CIImage(color: .black).cropped(to: extent)
        #expect(try Self.bytes(of: FieldRenderer.grained(black, index: 7, size: extent.size)).enumerated().allSatisfy { $0.offset % 4 == 3 || $0.element == 0 })
    }

    // MARK: - Documents

    @Test func aScenesFieldReplacesTheCanvassOnly() async throws {
        let json = #"""
            {"version": 1, "canvas": {"field": "ember"}, "style": {"accent": "#ff3b2f"},
             "scenes": [{"id": "one", "duration": 1}, {"id": "two", "duration": 1, "field": "halo"}]}
            """#
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8))
        let plan = await MotionPlan.build(document, bundle: URL.temporaryDirectory)

        #expect(plan.scenes.map(\.field) == [.ember, .halo])
        #expect(plan.scenes[0].palette == FieldPalette(.ember, accent: document.style.accent, background: document.canvas.background))
    }

    @Test func satinScenesTakeTheSetupsInTurn() async throws {
        let json = #"""
            {"version": 1, "canvas": {"field": "satin"},
             "scenes": [{"id": "one", "duration": 1}, {"id": "two", "duration": 1, "field": "halo"}, {"id": "three", "duration": 1},
                        {"id": "four", "duration": 1}]}
            """#
        let plan = await MotionPlan.build(try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8)), bundle: URL.temporaryDirectory)

        #expect(plan.scenes.map(\.fieldShot) == [0, 0, 1, 2])
    }

    /// A frame over satin is its shot's ground, moved as the camera moved since the scene began, with
    /// the film's grain over it.
    @Test func drawsSatinWhereTheCameraMovedIt() async throws {
        var scene = MotionScene(id: "pan", duration: 2)
        scene.camera.keyframes[.positionX] = [Keyframe(time: 0, value: 960), Keyframe(time: 1, value: 1060)]
        var document = MotionDocument(scenes: [scene])
        document.canvas.field = .satin
        let plan = await MotionPlan.build(document, bundle: URL.temporaryDirectory, shorterSide: 135)
        // The point the camera opened on is 100 canvas pixels left of the middle, 12.5 output pixels
        let ground = FieldRenderer.image(
            .satin, palette: plan.scenes[0].palette, at: 1, size: plan.outputSize, shot: FieldRenderer.Shot(shift: CGVector(dx: -12.5, dy: 0))
        )
        let expected = FieldRenderer.grained(ground, index: plan.frameRate, size: plan.outputSize)

        #expect(try Self.bytes(of: MotionFrameRenderer.image(at: 1, plan: plan)) == Self.bytes(of: expected))
    }

    @Test func editsSetTheCanvassAndASceneField() throws {
        var document = MotionDocument(scenes: [MotionScene(id: "one", duration: 1)])
        var canvas = MotionEdit(.setCanvas)
        canvas.canvas = MotionEdit.CanvasChange(field: .matrix)
        var scene = MotionEdit(.setScene, id: "one")
        scene.field = .halo

        try canvas.apply(to: &document)
        try scene.apply(to: &document)

        #expect(document.canvas.field == .matrix)
        #expect(document.scenes[0].field == .halo)
    }

    // MARK: - Helpers

    private static let background = RGBAColor(red: 0.031, green: 0.035, blue: 0.039, alpha: 1)

    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    private static func expect(_ color: RGBAColor, isNear hex: String, tolerance: Double = 2) throws {
        let expected = try #require(RGBAColor(hex: hex))
        let most = [color.red - expected.red, color.green - expected.green, color.blue - expected.blue].map { abs($0) * 255 }.max() ?? 0
        #expect(most <= tolerance, "\(color) isn't \(hex): \(most) of 255 off")
    }

    /// A field drawn at 240×135, as 8-bit RGBA.
    private static func pixels(_ field: MotionField, at time: Double, shot: FieldRenderer.Shot = FieldRenderer.Shot()) throws -> [UInt8] {
        let image = FieldRenderer.image(
            field, palette: FieldPalette(field, accent: RGBAColor(hex: "#3ecf8e"), background: background), at: time,
            size: CGSize(width: 240, height: 135), shot: shot
        )
        return try bytes(of: image)
    }

    /// The image's 240×135 pixels from the origin, as 8-bit RGBA.
    private static func bytes(of image: CIImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 240 * 135 * 4)
        context.render(image, toBitmap: &bytes, rowBytes: 240 * 4, bounds: CGRect(x: 0, y: 0, width: 240, height: 135), format: .RGBA8, colorSpace: nil)
        return bytes
    }

    /// The standard deviation of the green channel, in code values.
    private static func spread(of pixels: [UInt8]) -> Double {
        let green = stride(from: 1, to: pixels.count, by: 4).map { Double(pixels[$0]) }
        let mean = green.reduce(0, +) / Double(green.count)
        return (green.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(green.count)).squareRoot()
    }
}
