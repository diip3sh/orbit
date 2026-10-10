//
//  FlowFilmTests.swift
//  RecoTests
//

import CoreImage
import Foundation
import Testing
@testable import Reco

/// Flow films (spec 0016): the haze's white ground, a dive through a control, a melt, a mark's flight, a dragged selection.
struct FlowFilmTests {

    private static let size = CGSize(width: 240, height: 135)
    private static let red = CIImage(color: CIColor(red: 0.8, green: 0.1, blue: 0.1)).cropped(to: CGRect(origin: .zero, size: size))
    private static let blue = CIImage(color: CIColor(red: 0.1, green: 0.1, blue: 0.8)).cropped(to: CGRect(origin: .zero, size: size))

    /// White with the brand's light: a strong light's heart in the gradient's deepest colour, the frame away from it white.
    @Test func theHazeIsWhiteLitByTheBrand() throws {
        var style = StyleTokens()
        style.gradient = [RGBAColor(red: 0.49, green: 0.77, blue: 0.98, alpha: 1), RGBAColor(red: 0.02, green: 0.21, blue: 0.91, alpha: 1)]
        let palette = FieldPalette(.haze, style: style, background: RGBAColor(red: 1, green: 1, blue: 1, alpha: 1))
        #expect(OKLCH(palette.back).lightness > 0.97)
        // The second shot's deep blob comes in from the bottom left
        let field = FieldRenderer.image(.haze, palette: palette, at: 1, size: Self.size, shot: FieldRenderer.Shot(index: 1, start: 0))
        let (corner, away) = (try Self.color(of: field, at: CGPoint(x: 4, y: 4)), try Self.color(of: field, at: CGPoint(x: 236, y: 131)))
        #expect(corner[2] > 150 && corner[0] < 90, "\(corner)")
        #expect(away.allSatisfy { $0 > 225 }, "\(away)")
    }

    /// The camera flies through the source: the next scene shows through it at once, the scene before round it, and at the
    /// end the next scene fills the frame.
    @Test func aDiveFliesThroughItsSource() throws {
        let source = CGRect(x: 180, y: 60, width: 40, height: 20)
        let draw = { (progress: Double) in MotionFrameRenderer.dived(Self.red, into: Self.blue, from: source, progress: progress, size: Self.size) }

        let start = try draw(0.05)
        #expect(try Self.color(of: start, at: CGPoint(x: 200, y: 70))[2] > 150)
        #expect(try Self.color(of: start, at: CGPoint(x: 20, y: 20))[0] > 150)
        #expect(try Self.color(of: draw(1), at: CGPoint(x: 10, y: 10)) == Self.color(of: Self.blue, at: .zero))
        #expect(try Self.color(of: draw(1), at: CGPoint(x: 230, y: 125)) == Self.color(of: Self.blue, at: .zero))
    }

    /// A melt takes the scene before's darks first: part of the way, its dark half is the next scene and its light half still
    /// itself; it starts as the scene before and ends as the next.
    @Test func aMeltGoesDarksFirst() throws {
        let half = CGRect(x: 0, y: 0, width: Self.size.width / 2, height: Self.size.height)
        let before = CIImage(color: .black).cropped(to: half).composited(over: CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: Self.size)))
        let draw = { (progress: Double) in MotionFrameRenderer.melted(before, into: Self.blue, progress: progress, palette: nil, size: Self.size) }

        #expect(try Self.color(of: draw(0), at: CGPoint(x: 20, y: 67)) == [0, 0, 0])
        let middle = try draw(0.45)
        let dark = try Self.color(of: middle, at: CGPoint(x: 20, y: 67))
        let (end, next) = (try Self.color(of: draw(1), at: CGPoint(x: 220, y: 67)), try Self.color(of: Self.blue, at: .zero))
        #expect(zip(dark, next).allSatisfy { abs(Int($0) - Int($1)) <= 2 }, "\(dark) \(next)")
        #expect(try Self.color(of: middle, at: CGPoint(x: 220, y: 67)) == [255, 255, 255])
        #expect(zip(end, next).allSatisfy { abs(Int($0) - Int($1)) <= 2 }, "\(end) \(next)")
    }

    /// A fly comes from off to the side it travels away from, across fast and down late, so its path swoops; it lands level.
    @Test func aFlySwoopsOntoItsPlace() throws {
        let context = MoveContext(sceneDuration: 3, canvas: CGSize(width: 1920, height: 1080))
        let move = MotionMove(.fly, start: 0.5)
        let effect = MoveExpansion.effect(of: move, in: context)
        let value = { (property: MotionProperty, time: Double) in effect.tracks[property]?.reduce(0) { $0 + $1.value(at: time) } ?? 0 }

        #expect(value(.positionX, 0.5) > 1000 && value(.positionY, 0.5) < -300)
        let mid = 0.5 + MoveExpansion.flyDuration / 2
        // Across is mostly done half way through; down is not
        #expect(value(.positionX, mid) / value(.positionX, 0.5) < 0.2)
        #expect(value(.positionY, mid) / value(.positionY, 0.5) > 0.4)
        let landed = 0.5 + MoveExpansion.flyDuration
        #expect(abs(value(.positionX, landed)) < 1e-6 && abs(value(.positionY, landed)) < 1e-6 && abs(value(.rotationZ, landed)) < 1e-6)
    }

    /// A selection grows line by line over the text and the pointer drags along its end; it's pressed where it starts.
    @Test func aSelectionIsDraggedAcrossItsText() async throws {
        let message = #"{"id": "msg", "content": {"text": {"text": "Error 520\nSomething went wrong", "size": 80}}, "transform": {"position": [960, 540, 0]}, "#
            + #""moves": [{"move": "select", "start": 0.5}]}"#
        let json = #"{"version": 1, "scenes": [{"id": "one", "duration": 3, "layers": ["# + message + "]}]}"
        let plan = await MotionPlan.build(try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8)), bundle: URL.temporaryDirectory)
        let layer = try #require(plan.scenes[0].layers.first)
        let click = try #require(layer.clicks.first)
        let selection = try #require(click.sweep)

        #expect(click.press == 0.5 && layer.clicks.count == 1)
        #expect(selection.boxes(at: 0.4).isEmpty)
        let partway = selection.boxes(at: 0.5 + selection.duration * 0.3)
        #expect(partway.count == 1)
        let done = selection.boxes(at: 0.5 + selection.duration)
        #expect(done.count == 2 && done[1].minY > done[0].maxY - 1)
        #expect(selection.tip(at: 0.5).x < 0.05 && selection.tip(at: 0.5 + selection.duration).y > 0.5)
    }

    /// A dive sounds as air and a whoosh into a landing; a melt as a shimmer and a glass; a fly as a whoosh.
    @Test func eachSoundsAsItMoves() async throws {
        let mark = #"{"id": "mark", "content": {"shape": {"size": [100, 100], "color": "ff0000"}}, "transform": {"position": [960, 540, 0]}, "#
            + #""moves": [{"move": "fly", "start": 0.2}]}"#
        let json = #"{"version": 1, "scenes": [{"id": "one", "duration": 2}, {"id": "two", "duration": 2, "seam": "dive"}, "#
            + #"{"id": "three", "duration": 2, "seam": "melt", "layers": ["# + mark + "]}]}"
        let plan = await MotionPlan.build(try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8)), bundle: URL.temporaryDirectory)
        let cues = plan.sound.cues
        let near = { (time: Double, voice: (SoundCue.Voice) -> Bool) in
            cues.contains { abs($0.time - time) < 0.02 && voice($0.voice) }
        }
        let (dive, melt) = (plan.scenes[1].start, plan.scenes[2].start)
        let isWhoosh = { (voice: SoundCue.Voice) in if case .whoosh = voice { true } else { false } }
        let isGlass = { (voice: SoundCue.Voice) in if case .glass = voice { true } else { false } }

        #expect(near(dive + SoundRules.diveRiser.peak * SeamExpansion.diveDuration, isWhoosh))
        #expect(near(dive + SoundRules.diveLanding.at * SeamExpansion.diveDuration, isGlass))
        #expect(near(melt + SoundRules.meltShimmer.peak * SeamExpansion.meltDuration, isGlass))
        #expect(near(melt + 0.2 + SoundRules.flyWhoosh * MoveExpansion.flyDuration, isWhoosh))
    }

    // MARK: - Helpers

    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    /// The RGB bytes of the pixel at `point` (Core Image's coordinates, from the bottom left).
    private static func color(of image: CIImage, at point: CGPoint) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        context.render(image, toBitmap: &bytes, rowBytes: 4, bounds: CGRect(origin: point, size: CGSize(width: 1, height: 1)), format: .RGBA8, colorSpace: nil)
        return Array(bytes.prefix(3))
    }
}
