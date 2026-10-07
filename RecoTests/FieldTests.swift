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

    /// Satin keeps New Raycast's low key over time: its median 11–25 of 255 in the film, 5–39 in
    /// the prototype it was tuned on, its crests rolling off well below white.
    @Test func keepsSatinLowKey() throws {
        for time in stride(from: 0.0, through: 30, by: 6) {
            let green = try Self.pixels(.satin, at: time).enumerated().filter { $0.offset % 4 == 1 }.map(\.element).sorted()
            let median = green[green.count / 2]
            let top = green[green.count * 99 / 100]
            #expect((2...45).contains(median), "satin at \(time) s: median \(median)")
            #expect(top < 200, "satin at \(time) s: 99th percentile \(top)")
        }
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
    private static func pixels(_ field: MotionField, at time: Double) throws -> [UInt8] {
        let extent = CGRect(x: 0, y: 0, width: 240, height: 135)
        let image = FieldRenderer.image(
            field, palette: FieldPalette(field, accent: RGBAColor(hex: "#3ecf8e"), background: background), at: time, size: extent.size
        )
        var bytes = [UInt8](repeating: 0, count: 240 * 135 * 4)
        context.render(image, toBitmap: &bytes, rowBytes: 240 * 4, bounds: extent, format: .RGBA8, colorSpace: nil)
        return bytes
    }

    /// The standard deviation of the green channel, in code values.
    private static func spread(of pixels: [UInt8]) -> Double {
        let green = stride(from: 1, to: pixels.count, by: 4).map { Double(pixels[$0]) }
        let mean = green.reduce(0, +) / Double(green.count)
        return (green.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(green.count)).squareRoot()
    }
}
