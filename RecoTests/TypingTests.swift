//
//  TypingTests.swift
//  RecoTests
//

import CoreImage
import Foundation
import Testing
@testable import Reco

/// Typing into a lifted field as a person does (spec 0012, the film's port, phase 3): the pace, the
/// results settling, the caret, the field growing, and what a frame shows.
struct TypingTests {

    /// "row level security" at the film's pace: 7–8 keys a second, slower round each space, the same
    /// every time.
    @Test func typesAtAHumanPace() {
        let keys = HumanTyping.keyTimes(for: "row level security", from: 1)
        let steps = zip(keys.dropFirst(), keys).map { $0 - $1 }

        #expect(keys.count == 18 && keys.first == 1)
        #expect(steps.allSatisfy { $0 > 0.07 })
        #expect((2.2...2.6).contains(keys[17] - keys[0]))
        // Into and out of each space, against the usual step
        let median = steps.sorted()[steps.count / 2]
        #expect(steps[2] + steps[3] > 2 * median + 0.05)
        #expect(steps[8] + steps[9] > 2 * median + 0.05)
        #expect(HumanTyping.keyTimes(for: "row level security", from: 1) == keys)
    }

    @Test func settlesWhenAWordEnds() {
        #expect(HumanTyping.settledLengths(of: "row level security") == [3, 9, 18])
        #expect(HumanTyping.settledLengths(of: "search") == [6])
    }

    /// Solid for 0.5 s after a key, then on and off every 0.53 s with short fades.
    @Test func blinksAsMacOSDoes() {
        #expect(HumanTyping.caretOpacity(at: 0.9, since: 1) == 0)
        #expect(HumanTyping.caretOpacity(at: 1.4, since: 1) == 1)
        #expect(HumanTyping.caretOpacity(at: 1.7, since: 1) == 1)
        #expect(HumanTyping.caretOpacity(at: 2.3, since: 1) == 0)
        let fading = HumanTyping.caretOpacity(at: 1.99, since: 1)
        #expect(fading > 0 && fading < 1)
        #expect(HumanTyping.caretOpacity(at: 2.6, since: 1) == 1)
    }

    @Test func growsOnASpring() {
        #expect(HumanTyping.growth(after: 0) == 0)
        #expect(abs(HumanTyping.growth(after: 0.3) - 0.95) < 0.01)
        #expect(HumanTyping.growth(after: 1) > 0.999)
    }

    /// The plan types "ab" from 0.5 s: the field as tall as its results, each letter's row, the results
    /// 0.22 s after the word ends, the field growing to them, the caret past the text.
    @Test func plansAFieldBeingTyped() async throws {
        let (url, document) = try MotionTestBundle.makeTyping()
        defer { try? FileManager.default.removeItem(at: url) }

        let layer = await MotionPlan.build(document, bundle: url, shorterSide: 1080).scenes[0].layers[0]
        let typing = try #require(layer.typing)

        #expect(layer.size == CGSize(width: 576, height: 200))
        #expect(layer.image == nil)
        #expect(typing.keys.count == 2 && typing.keys[0] == 0.5)
        #expect(typing.length(at: 0.4) == 0 && typing.length(at: 1) == 2)
        #expect(typing.state(at: typing.keys[1] + 0.2) == 0 && typing.state(at: typing.keys[1] + 0.25) == 1)
        #expect(typing.height(at: 0.4) == 48 && abs(typing.height(at: 2.5) - 200) < 0.01)
        #expect(abs(typing.caret(at: 0.4).frame.minX - (40 - 0.097 * 16 - 0.077 * 16)) < 1e-9)
        #expect(abs(typing.caret(at: 1).frame.minX - (60 + 0.037 * 16)) < 1e-9)
        #expect(typing.caret(at: typing.keys[1] + 0.1).opacity == 1)
    }

    /// Before typing the field is its row alone; once the results settle they show under it, on the
    /// glass grown to hold them.
    @Test func drawsTheResultsOnceTheySettle() async throws {
        let (url, document) = try MotionTestBundle.makeTyping()
        defer { try? FileManager.default.removeItem(at: url) }
        let plan = await MotionPlan.build(document, bundle: url, shorterSide: 1080)
        // The field spans y 440–640; its results bar runs from x 712 at y 530–544
        let before = try Self.green(MotionFrameRenderer.image(at: 0.4, plan: plan), at: CGPoint(x: 800, y: 537))
        let after = try Self.green(MotionFrameRenderer.image(at: 1.9, plan: plan), at: CGPoint(x: 800, y: 537))

        #expect(before < 60)
        #expect(after > 180)
    }

    /// The presses move the selection down and back up, never above the first result; the camera
    /// follows each move 0.06 s late over 0.3 s, by how far the selected result moved.
    @Test func followsTheSelection() async throws {
        let (url, document) = try MotionTestBundle.makeTyping()
        defer { try? FileManager.default.removeItem(at: url) }
        let plan = await MotionPlan.build(document, bundle: url, shorterSide: 1080)
        let typing = try #require(plan.scenes[0].layers[0].typing)
        let lookingDown = { (time: Double) in plan.scenes[0].cameraValue(.positionY, at: time) - 540 }

        #expect([1.9, 2.1, 2.6, 2.9].map(typing.selection(at:)) == [0, 1, 0, 0])
        // The second press up moves nothing, so it has no move
        #expect(typing.follow().count == 2)
        #expect(lookingDown(2.05) == 0)
        #expect(abs(lookingDown(2.36) - 40 * TypedField.followShare) < 1e-9)
        #expect(lookingDown(2.2) > 20 && lookingDown(2.2) < 38)
        #expect(abs(lookingDown(2.9)) < 1e-9)
    }

    /// Selected, the next result shows as the selected lift draws it.
    @Test func drawsTheSelectedResult() async throws {
        let (url, document) = try MotionTestBundle.makeTyping()
        defer { try? FileManager.default.removeItem(at: url) }
        let plan = await MotionPlan.build(document, bundle: url, shorterSide: 1080)
        // The second bar is at y 130–144 of the field, which the camera follows down by 38 at 2.4 s
        let selected = try Self.green(MotionFrameRenderer.image(at: 2.45, plan: plan), at: CGPoint(x: 800, y: 440 + 137 - 38))
        let unselected = try Self.green(MotionFrameRenderer.image(at: 1.9, plan: plan), at: CGPoint(x: 800, y: 440 + 137))

        #expect(selected > 180)
        #expect(unselected < 60)
    }

    /// A whip is sampled every 3 pixels a point travels in an export, up to 96 times; the editor
    /// keeps every 4.
    @Test func samplesAWhipAsTheFilmDid() {
        #expect(FrameRenderer.blurOffsets(distance: 30, most: 96, spacing: 3).count == 10)
        #expect(FrameRenderer.blurOffsets(distance: 600, most: 96, spacing: 3).count == 96)
        #expect(FrameRenderer.blurOffsets(distance: 30, most: 16).count == 8)
    }

    /// Typing is lifted apart from the plain still.
    @Test func keysTypingLiftsApart() throws {
        var asset = MotionAsset(id: "search", url: try #require(URL(string: "https://example.com")), selector: "#search")
        let bundle = URL(filePath: "/bundle.motion")
        let plain = UILiftCache.url(of: asset, scale: 2, in: bundle)
        asset.typing = MotionAsset.Typing(field: "#q", text: "ab")

        #expect(UILiftCache.url(of: asset, scale: 2, in: bundle) != plain)
    }

    /// The green level at `point` (from the top-left) of a 1920×1080 frame.
    private static func green(_ image: CIImage, at point: CGPoint) throws -> Int {
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(
            image, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: point.x, y: 1080 - point.y - 1, width: 1, height: 1), format: .RGBA8, colorSpace: nil
        )
        return Int(pixel[1])
    }
}
