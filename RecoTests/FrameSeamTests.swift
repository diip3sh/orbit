//
//  FrameSeamTests.swift
//  RecoTests
//

import CoreImage
import Foundation
import Testing
@testable import Reco

/// Seams that move whole frames as things: a card rising over the scene before, a click opening into the next.
struct FrameSeamTests {

    private static let size = CGSize(width: 240, height: 135)
    private static let before = CIImage(color: CIColor(red: 0.8, green: 0.1, blue: 0.1)).cropped(to: CGRect(origin: .zero, size: size))
    private static let next = CIImage(color: CIColor(red: 0.1, green: 0.1, blue: 0.8)).cropped(to: CGRect(origin: .zero, size: size))

    /// The card comes up from below over the scene before, which darkens as it goes back; it ends as the next scene.
    @Test func aStackRisesOverTheSceneBefore() throws {
        let draw = { (progress: Double) in MotionFrameRenderer.stacked(Self.before, under: Self.next, progress: progress, size: Self.size) }

        let (start, plain) = (try Self.color(of: draw(0), at: CGPoint(x: 120, y: 60)), try Self.color(of: Self.before, at: .zero))
        #expect(start == plain, "\(start) \(plain)")
        let middle = try draw(0.5)
        // The card's top edge is half way up: the next scene under it, the scene before above it, darker
        #expect(try Self.color(of: middle, at: CGPoint(x: 120, y: 20))[2] > 150)
        let above = try Self.color(of: middle, at: CGPoint(x: 120, y: 120))
        #expect(above[0] > above[2] && above[0] < 190)
        #expect(try Self.color(of: draw(1), at: CGPoint(x: 120, y: 120)) == Self.color(of: Self.next, at: .zero))
    }

    /// The next scene opens out of the box it starts from and ends filling the frame.
    @Test func anExpandOpensOutOfItsSource() throws {
        let source = CGRect(x: 180, y: 60, width: 40, height: 20)
        let draw = { (progress: Double) in
            MotionFrameRenderer.expanded(Self.before, into: Self.next, from: source, progress: progress, size: Self.size)
        }

        let start = try draw(0.1)
        #expect(try Self.color(of: start, at: CGPoint(x: 200, y: 70))[2] > 150)
        #expect(try Self.color(of: start, at: CGPoint(x: 10, y: 10))[0] > 150)
        #expect(try Self.color(of: draw(1), at: CGPoint(x: 10, y: 10)) == Self.color(of: Self.next, at: .zero))
    }

    /// It opens from what the scene before clicked last, where that is at the scene's end; without a click, the middle.
    @Test func anExpandOpensFromTheLastClick() async throws {
        let button = #"{"id": "button", "content": {"shape": {"size": [200, 100], "color": "333333"}}, "transform": {"position": [1500, 300, 0]},"#
            + #" "moves": [{"move": "click", "start": 0.5}]}"#
        let json = #"{"version": 1, "scenes": [{"id": "one", "duration": 2, "layers": ["# + button
            + #"]}, {"id": "two", "duration": 2, "seam": "expand"}, {"id": "three", "duration": 2, "seam": "expand"}]}"#
        let plan = await MotionPlan.build(try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8)), bundle: URL.temporaryDirectory)

        #expect(plan.scenes[1].transition?.seam == .expand)
        let source = MotionFrameRenderer.expandSource(into: 1, plan: plan)
        #expect(abs(source.midX - 1500) < 1 && abs(source.midY - (1080 - 300)) < 1)
        #expect(abs(source.width - 200) < 1 && abs(source.height - 100) < 1)
        let middle = MotionFrameRenderer.expandSource(into: 2, plan: plan)
        #expect(abs(middle.midX - 960) < 1 && abs(middle.midY - 540) < 1)
    }

    /// The moving edge is motion blurred while it travels, and not once the seam is over.
    @Test func theCardIsBlurredWhileItTravels() async throws {
        let json = #"{"version": 1, "scenes": [{"id": "one", "duration": 2}, {"id": "two", "duration": 2, "seam": "stack"}]}"#
        let plan = await MotionPlan.build(try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8)), bundle: URL.temporaryDirectory)
        let travel = { (time: Double) in MotionFrameRenderer.seamTravel(of: plan.scenes[1], at: time, across: 1.0 / 60, size: plan.outputSize) }

        #expect(travel(0.1) > 10)
        #expect(travel(1) == 0)
        #expect(MotionFrameRenderer.seamTravel(of: plan.scenes[0], at: 0.1, across: 1.0 / 60, size: plan.outputSize) == 0)
    }

    /// A stack sounds as air and a soft landing, an expand as air opening and a glass; neither as a cut's swish and hit.
    @Test func eachSoundsAsItMoves() async throws {
        let json = #"{"version": 1, "scenes": [{"id": "one", "duration": 2}, {"id": "two", "duration": 2, "seam": "stack"}, "#
            + #"{"id": "three", "duration": 2, "seam": "expand"}]}"#
        let plan = await MotionPlan.build(try JSONDecoder().decode(MotionDocument.self, from: Data(json.utf8)), bundle: URL.temporaryDirectory)
        let cues = plan.sound.cues
        let near = { (time: Double) in { (cue: SoundCue) in abs(cue.time - time) < 0.02 } }
        let (stack, expand) = (plan.scenes[1].start, plan.scenes[2].start)

        #expect(cues.contains { if case .swish = $0.voice { near(stack)($0) } else { false } })
        #expect(cues.contains { if case .thump = $0.voice { near(stack + SoundRules.stackLanding.at * SeamExpansion.stackDuration)($0) } else { false } })
        #expect(!cues.contains { if case .thump = $0.voice { near(stack)($0) } else { false } })
        let open = expand + SoundRules.expandRiser.peak * SeamExpansion.expandDuration
        #expect(cues.contains { if case .riser = $0.voice { near(open)($0) } else { false } })
        #expect(cues.contains { if case .glass = $0.voice { near(open)($0) } else { false } })
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
