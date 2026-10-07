//
//  WebScriptTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

struct WebScriptTests {

    private let button = WebTarget(selector: "#buy", point: CGPoint(x: 100, y: 100))
    private let link = WebTarget(selector: "a.nav", point: CGPoint(x: 500, y: 40))

    @Test func easingFollowsCSSsCurves() {
        #expect(Easing.linear(0.3) == 0.3)
        for easing in Easing.allCases {
            #expect(abs(easing(0)) < 1e-6)
            #expect(abs(easing(1) - 1) < 1e-6)
            #expect(easing(-1) == easing(0))
            #expect(easing(2) == easing(1))
        }
        // Reference values of CSS's ease-in and ease-out at half time
        #expect(abs(Easing.easeIn(0.5) - 0.3153) < 1e-3)
        #expect(abs(Easing.easeOut(0.5) - 0.6847) < 1e-3)
        #expect(abs(Easing.easeInOut(0.5) - 0.5) < 1e-6)
        #expect(Easing.easeInOut(0.25) < 0.25)
    }

    @Test func scrollsFromWhereThePreviousClipEnded() {
        var script = WebScript()
        script.scrolls = [
            ScrollClip(range: 1..<2, offset: CGPoint(x: 0, y: 500), easing: .linear),
            ScrollClip(range: 3..<5, offset: CGPoint(x: 0, y: 1500), easing: .linear)
        ]

        #expect(script.scrollOffset(at: 0) == .zero)
        #expect(script.scrollOffset(at: 1) == .zero)
        #expect(script.scrollOffset(at: 1.5) == CGPoint(x: 0, y: 250))
        #expect(script.scrollOffset(at: 2) == CGPoint(x: 0, y: 500))
        #expect(script.scrollOffset(at: 2.5) == CGPoint(x: 0, y: 500))
        #expect(script.scrollOffset(at: 4) == CGPoint(x: 0, y: 1000))
        #expect(script.scrollOffset(at: 9) == CGPoint(x: 0, y: 1500))
    }

    @Test func scrollsEaseAlongTheClip() {
        var script = WebScript()
        script.scrolls = [ScrollClip(range: 0..<1, offset: CGPoint(x: 0, y: 1000), easing: .easeIn)]

        #expect(abs(script.scrollOffset(at: 0.5).y - 1000 * Easing.easeIn(0.5)) < 1e-9)
    }

    @Test func theCursorFollowsRestsAndTravels() {
        var script = WebScript()
        #expect(script.pointerPosition(at: 1) == nil)

        script.pointer = [
            PointerClip(range: 1..<2, action: .hover, target: button),
            PointerClip(range: 4..<5, action: .click, target: link)
        ]

        // Waiting in the middle of the view, then travelling in to arrive as the first clip starts
        let entry = WebTarget(point: CGPoint(x: 720, y: 450))
        #expect(script.pointerPosition(at: 0) == .resting(entry))
        #expect(script.pointerPosition(at: 0.5) == .travelling(start: entry, end: button, progress: Easing.easeInOut(0.5)))
        #expect(script.pointerPosition(at: 1.5) == .following(button))
        // The 2 s gap is spent resting for 1 s, then travelling for the longest travel
        #expect(script.pointerPosition(at: 2.5) == .resting(button))
        #expect(script.pointerPosition(at: 3) == .resting(button))
        #expect(script.pointerPosition(at: 3.5) == .travelling(start: button, end: link, progress: Easing.easeInOut(0.5)))
        #expect(script.pointerPosition(at: 4) == .following(link))
        #expect(script.pointerPosition(at: 9) == .resting(link))
    }

    /// A hand typing isn't on the mouse: the cursor stops following its field from the first key.
    @Test func restsOnceAClipTypes() throws {
        var script = WebScript()
        var typing = PointerClip(range: 1..<3, action: .click, target: button)
        typing.text = "stripe"
        script.pointer = [typing]
        let firstKey = try #require(typing.keystrokes.first?.time)

        #expect(script.pointerPosition(at: 1.1) == .following(button))
        #expect(script.pointerPosition(at: firstKey + 0.01) == .resting(button))
        #expect(script.pointerPosition(at: 2.9) == .resting(button))
    }

    @Test func aShortGapIsAllTravel() {
        var script = WebScript()
        script.pointer = [
            PointerClip(range: 0..<1, action: .hover, target: button),
            PointerClip(range: 1.4..<2, action: .hover, target: link)
        ]

        #expect(script.pointerPosition(at: 1.2) == .travelling(start: button, end: link, progress: Easing.easeInOut(0.5)))
    }

    @Test func theCursorFollowsItsTargetOnlyDuringAClip() {
        var script = WebScript()
        script.pointer = [
            PointerClip(range: 0..<1, action: .hover, target: button),
            PointerClip(range: 3..<4, action: .hover, target: link)
        ]
        var track = PointerTrack(script: script)
        let buttonAt = { (top: Double) in ["#buy": CGRect(x: 90, y: top, width: 20, height: 20)] }

        #expect(track.selectors(at: 0.5) == ["#buy"])
        #expect(track.location(at: 0.5, elementFrames: buttonAt(90)) == CGPoint(x: 100, y: 100))
        #expect(track.location(at: 0.9, elementFrames: buttonAt(40)) == CGPoint(x: 100, y: 50))
        // Resting, it stays put while the page scrolls the button away, then travels from there
        #expect(track.selectors(at: 1.5).isEmpty)
        #expect(track.location(at: 1.5, elementFrames: [:]) == CGPoint(x: 100, y: 50))
        #expect(track.selectors(at: 2.5) == ["a.nav"])
        let linkFrame = ["a.nav": CGRect(x: 490, y: 30, width: 20, height: 20)]
        #expect(track.location(at: 2.5, elementFrames: linkFrame) == WebScript.travelPoint(
            from: CGPoint(x: 100, y: 50), to: CGPoint(x: 500, y: 40), progress: Easing.easeInOut(0.5)
        ))
        #expect(track.location(at: 3.5, elementFrames: linkFrame) == CGPoint(x: 500, y: 40))
    }

    @Test func clicksPressAtTheStartAndReleaseSoonAfter() {
        var script = WebScript()
        script.pointer = [
            PointerClip(range: 1..<2, action: .hover, target: button),
            PointerClip(range: 4..<5, action: .click, target: link)
        ]

        #expect(script.presses(after: -.infinity, through: 10).map(\.time) == [4, 4.1])
        #expect(script.presses(after: 3.99, through: 4) == [WebScript.Press(time: 4, isDown: true, target: link)])
        #expect(script.presses(after: 4, through: 4.1) == [WebScript.Press(time: 4.1, isDown: false, target: link)])
        #expect(script.presses(after: 4.1, through: 10).isEmpty)
        // 0.2 + 0.1 is a hair past 0.3, and still lands on the frame at 0.3 s
        script.pointer = [PointerClip(range: 0.2..<0.5, action: .click, target: link)]
        #expect(script.presses(after: 17.0 / 60, through: 18.0 / 60).map(\.isDown) == [false])
        #expect(script.presses(after: 18.0 / 60, through: 19.0 / 60).isEmpty)
    }

    @Test func travelBowsToTheLeftOfTheDirection() {
        let start = CGPoint(x: 0, y: 0)
        let end = CGPoint(x: 100, y: 0)

        #expect(WebScript.travelPoint(from: start, to: end, progress: 0) == start)
        #expect(WebScript.travelPoint(from: start, to: end, progress: 1) == end)
        // Moving right, left is up: 10% of the distance at the middle
        let middle = WebScript.travelPoint(from: start, to: end, progress: 0.5)
        #expect(abs(middle.x - 50) < 1e-9)
        #expect(abs(middle.y + 10) < 1e-9)
    }

    @Test func aTargetIsItsElementsAnchorOrItsPoint() {
        var target = button
        target.anchor = CGPoint(x: 0.25, y: 0.5)

        #expect(target.location(elementFrame: CGRect(x: 10, y: 20, width: 40, height: 10)) == CGPoint(x: 20, y: 25))
        #expect(target.location(elementFrame: nil) == CGPoint(x: 100, y: 100))
    }

    @Test func clipsFitWhereThereIsRoom() {
        let clips = [PointerClip(range: 2..<3, action: .hover, target: button)]

        #expect(clips.room(at: 0, length: PointerClip.defaultDuration, duration: 10) == 0..<1)
        #expect(clips.room(at: 1.5, length: PointerClip.defaultDuration, duration: 10) == 1.5..<2)
        #expect(clips.room(at: 1.9, length: PointerClip.defaultDuration, duration: 10) == nil)
        #expect(clips.room(at: 2.5, length: PointerClip.defaultDuration, duration: 10) == nil)
    }

    @Test func sizesAndLengths() {
        var script = WebScript()
        script.duration = 2.5
        script.pointer = [PointerClip(range: 2..<3.5, action: .hover, target: button)]

        #expect(script.videoSize == CGSize(width: 2880, height: 1800))
        #expect(script.frameCount == 150)
        #expect(script.minimumAllowedDuration == 3.5)
    }

    @Test func roundTripsThroughJSON() throws {
        var script = WebScript()
        script.url = URL(string: "https://example.com")
        script.pointer = [PointerClip(range: 1..<2, action: .click, target: button)]
        script.scrolls = [
            ScrollClip(range: 0..<1, offset: CGPoint(x: 0, y: 900), easing: .easeOut),
            ScrollClip(range: 1..<2, offset: CGPoint(x: 0, y: 1500), target: .init(selector: "#faq", placement: .intoView))
        ]

        let decoded = try JSONDecoder().decode(WebScript.self, from: JSONEncoder().encode(script))

        #expect(decoded == script)
    }

    @Test func theCursorStaysInTheViewWhenItsElementLeavesIt() {
        var script = WebScript()
        script.pointer = [
            PointerClip(range: 0..<1, action: .hover, target: button),
            PointerClip(range: 2..<3, action: .hover, target: link)
        ]
        var track = PointerTrack(script: script)

        // Scrolled off the top, as a page scrolling under a hover can take it
        #expect(track.location(at: 0.5, elementFrames: ["#buy": CGRect(x: 90, y: -300, width: 20, height: 20)]) == CGPoint(x: 100, y: 0))
        // The travel's arc, which bows up between two targets at the top, stays in too
        let travelling = track.location(at: 1.5, elementFrames: ["a.nav": CGRect(x: 1390, y: 0, width: 20, height: 20)])
        #expect(travelling?.y == 0)
    }

    @Test func aScrollToAnElementAimsAtWhereItIsWhenTheScrollStarts() {
        let viewport = CGSize(width: 1440, height: 900)
        let margin = CGFloat(ScrollClip.Target.topMargin * 900)
        let current = CGPoint(x: 0, y: 500)
        let top = ScrollClip.Target(selector: "h2", placement: .top)
        let intoView = ScrollClip.Target(selector: "a", placement: .intoView)
        func offset(_ target: ScrollClip.Target, _ box: CGRect, pageHeight: Double = 5000) -> CGFloat {
            target.offset(showing: box, from: current, viewport: viewport, pageHeight: pageHeight).y
        }

        // Near the top, wherever it is
        #expect(offset(top, CGRect(x: 0, y: 1000, width: 10, height: 40)) == 500 + 1000 - margin)
        #expect(offset(top, CGRect(x: 0, y: 300, width: 10, height: 40)) == 500 + 300 - margin)
        // Into view only when it isn't, and only as far as it takes
        #expect(offset(intoView, CGRect(x: 0, y: 300, width: 10, height: 40)) == 500)
        #expect(offset(intoView, CGRect(x: 0, y: 1000, width: 10, height: 40)) == 500 + 1040 - 900 + margin)
        #expect(offset(intoView, CGRect(x: 0, y: -100, width: 10, height: 40)) == 500 - 100 - margin)
        // Too tall for the view: its middle in the middle, unless it's in view already
        #expect(offset(intoView, CGRect(x: 0, y: -200, width: 10, height: 1200)) == 500)
        #expect(offset(intoView, CGRect(x: 0, y: 600, width: 10, height: 1200)) == CGFloat(500 + 1200 - 450))
        // Inside the page
        #expect(offset(top, CGRect(x: 0, y: 4000, width: 10, height: 40), pageHeight: 3000) == 2100)
        #expect(offset(intoView, CGRect(x: 0, y: -1000, width: 10, height: 40)) == 0)
    }

    @Test func aClickTypesItsTextKeyByKeyAfterThePress() {
        var script = WebScript()
        let field = WebTarget(selector: "#name", point: .zero)
        script.pointer = [
            PointerClip(range: 1..<3, action: .click, target: field, text: "Hi!"),
            PointerClip(range: 4..<5, action: .hover, target: field, text: "never typed")
        ]

        #expect(script.keystrokes(after: 0, through: 1.29).isEmpty)
        #expect(script.keystrokes(after: 1.29, through: 1.3).map(\.character) == ["H"])
        #expect(script.keystrokes(after: 1.3, through: 1.5).map(\.character) == ["i", "!"])
        #expect(script.keystrokes(after: 1.5, through: 10).isEmpty)
        #expect(script.keystrokes(after: 0, through: 10).allSatisfy { $0.target == field })
    }

    @Test func typingFitsAClipTooShortForItsText() {
        let clip = PointerClip(range: 0..<0.4, action: .click, target: WebTarget(point: .zero), text: "abcdefghij")

        let times = clip.keystrokes.map(\.time)

        // From half-way, 0.02 s apart instead of 0.08
        #expect(times.count == 10 && abs(times[0] - 0.2) < 1e-9 && abs(times[9] - 0.38) < 1e-9)
    }

    @Test func aUSKeyboardsKeysForCharacters() {
        #expect(USKeyCodes.key(for: "a").map { [$0.keyCode, $0.shift ? 1 : 0] } == [0, 0])
        #expect(USKeyCodes.key(for: "A").map { [$0.keyCode, $0.shift ? 1 : 0] } == [0, 1])
        #expect(USKeyCodes.key(for: "?").map { [$0.keyCode, $0.shift ? 1 : 0] } == [44, 1])
        #expect(USKeyCodes.key(for: "\n").map { [$0.keyCode, $0.shift ? 1 : 0] } == [36, 0])
        #expect(USKeyCodes.key(for: "é") == nil && USKeyCodes.key(for: "🙂") == nil)
    }
}
