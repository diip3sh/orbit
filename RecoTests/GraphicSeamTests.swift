//
//  GraphicSeamTests.swift
//  RecoTests
//

import CoreImage
import Foundation
import Testing
@testable import Reco

/// The graphic seams any look may use (spec 0019): each starts on the scene before and ends on the next, in the brand's colours,
/// and two of a kind in one film go different ways.
struct GraphicSeamTests {

    /// Each starts on the scene before and ends on the next (within a level), and half way is neither.
    @Test(arguments: MotionSeam.graphic.sorted { $0.rawValue < $1.rawValue })
    func drawsFromTheSceneBeforeToTheNext(seam: MotionSeam) throws {
        var transition = SeamExpansion.Transition(seam: seam, duration: SeamExpansion.graphicDurations[seam] ?? 1)
        transition.colors = StyleTokens(accent: Self.color("#3ecf8e")).seamColors
        let draw = { (progress: Double) in
            try Self.bytes(of: TransitionRenderer.draw(
                transition, between: (Self.outgoing, Self.incoming), at: (progress, progress * transition.duration), origin: nil, size: Self.size
            ))
        }

        let (before, after, middle) = (try Self.bytes(of: Self.outgoing), try Self.bytes(of: Self.incoming), try draw(0.5))
        #expect(Self.most(try draw(0), before) <= 1)
        #expect(Self.most(try draw(1), after) <= 1)
        #expect(Self.most(middle, before) > 40 && Self.most(middle, after) > 40)
    }

    /// A graphic seam takes the brand's two colours and its scene's index; its length is its own.
    @Test func takesTheBrandsColoursAndItsPlace() async throws {
        let json = #"""
            {"version": 1, "canvas": {"field": "paper"}, "style": {"accent": "#ff5a1f"},
             "scenes": [{"id": "one", "duration": 2}, {"id": "two", "duration": 2, "seam": "bars"}, {"id": "three", "duration": 2, "seam": "bars"},
                        {"id": "four", "duration": 2, "seam": "iris"}]}
            """#
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8))
        let plan = await MotionPlan.build(document, bundle: URL.temporaryDirectory, shorterSide: 135)

        let bars = try #require(plan.scenes[1].transition)
        #expect(bars.colors == document.style.seamColors && bars.variant == 1)
        #expect(plan.scenes[2].transition?.variant == 2)
        #expect(plan.scenes[3].transition?.duration == SeamExpansion.graphicDurations[.iris])
        #expect(plan.scenes[2].overlap == SeamExpansion.graphicDurations[.iris])
        #expect(MotionLint.findings(in: document).filter { $0.rule == .look }.isEmpty)
    }

    /// One colour gives it a quarter lighter or darker; a gradient its other end.
    @Test func seamColoursAreTheBrands() {
        let dark = StyleTokens(accent: Self.color("#1b4dff")).seamColors
        #expect(dark.count == 2 && abs(OKLCH(dark[1]).lightness - OKLCH(dark[0]).lightness - StyleTokens.seamTint) < 0.02)
        let light = StyleTokens(accent: Self.color("#c8f560")).seamColors
        #expect(OKLCH(light[1]).lightness < OKLCH(light[0]).lightness)
        let gradient = StyleTokens(accent: Self.color("#ff5a1f"), gradient: [Self.color("#ffd000"), Self.color("#ff2e88")]).seamColors
        #expect(gradient == [Self.color("#ff5a1f"), Self.color("#ff2e88")])
    }

    /// Between scenes on the accent, the brand's colour gives way to what stands out: the text's or the background.
    @Test func seamColoursStandOutFromTheGrounds() async throws {
        let style = StyleTokens(text: Self.color("#f4f1ea"), accent: Self.color("#ff5a1f"))
        let background = Self.color("#0f1115")
        #expect(style.seamColors(between: [background], background: background) == style.seamColors)
        let onAccent = style.seamColors(between: [Self.color("#ff5a1f"), Self.color("#ff6a2f")], background: background)
        #expect(!onAccent.contains(Self.color("#ff5a1f")) && onAccent.count == 2)

        let json = #"""
            {"version": 1, "canvas": {"background": "#0f1115"}, "style": {"accent": "#ff5a1f", "text": "#f4f1ea"},
             "scenes": [{"id": "one", "duration": 2, "layers": [
                {"id": "ground", "content": {"shape": {"size": [1920, 1080], "color": "#ff5a1f"}}, "transform": {"position": [960, 540, 0]}}]},
                {"id": "two", "duration": 2, "seam": "liquid"}]}
            """#
        let document = try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8))
        let plan = await MotionPlan.build(document, bundle: URL.temporaryDirectory, shorterSide: 135)
        #expect(plan.scenes[1].transition?.colors == style.seamColors(between: [Self.color("#ff5a1f"), background], background: background))
        #expect(plan.scenes[1].transition?.colors.first != Self.color("#ff5a1f"))
    }

    /// Bars and slats land, an iris opens with a glass, a flash hits on its peak.
    @Test func eachHasItsSound() {
        var cues = SoundCueList(frameRate: 60)
        cues.graphic(.bars, at: 1, lasting: 0.7)
        #expect(cues.list.count == 4)
        var flash = SoundCueList(frameRate: 60)
        flash.graphic(.flash, at: 2, lasting: 0.35)
        #expect(flash.list.contains { abs($0.time - flash.frame(2 + TransitionRenderer.flashPeak * 0.35)) < 1e-9 })
    }

    // MARK: - Frames

    private static let size = CGSize(width: 240, height: 136)

    /// Red with a white square, and blue with a yellow band: things to tell apart in blocks and bands.
    private static let outgoing = CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: CGRect(x: 40, y: 30, width: 50, height: 50))
        .composited(over: CIImage(color: CIColor(red: 0.8, green: 0.1, blue: 0.1)).cropped(to: CGRect(origin: .zero, size: size)))
    private static let incoming = CIImage(color: CIColor(red: 1, green: 0.85, blue: 0)).cropped(to: CGRect(x: 0, y: 60, width: 240, height: 20))
        .composited(over: CIImage(color: CIColor(red: 0.1, green: 0.1, blue: 0.8)).cropped(to: CGRect(origin: .zero, size: size)))

    private static func color(_ hex: String) -> RGBAColor {
        RGBAColor(hex: hex) ?? RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
    }

    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    private static func bytes(of image: CIImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: Int(size.width * size.height) * 4)
        context.render(image, toBitmap: &bytes, rowBytes: Int(size.width) * 4, bounds: CGRect(origin: .zero, size: size), format: .RGBA8, colorSpace: nil)
        return bytes
    }

    private static func most(_ one: [UInt8], _ other: [UInt8]) -> Int {
        zip(one, other).map { abs(Int($0) - Int($1)) }.max() ?? 0
    }
}
