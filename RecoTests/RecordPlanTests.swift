//
//  RecordPlanTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

struct RecordPlanTests {

    private typealias Step = RecordPageRequest.Step

    private func page(height: Double = 3000, boxes: [String: PageInspection.Box]? = [:]) -> PageInspection {
        PageInspection(
            title: "Test", url: "https://example.com", viewport: .init(width: 1440, height: 900),
            pageHeight: height, elements: [], truncated: false, boxes: boxes
        )
    }

    private func plan(_ steps: [Step]) throws -> RecordPlan {
        try RecordPageRequest(url: "example.com", steps: steps).plan()
    }

    private func scrollTop(of selector: String, at top: Double, height: Double = 3000) throws -> CGFloat? {
        let boxes = [selector: PageInspection.Box(left: 0, top: top, width: 100, height: 50)]
        let script = try plan([Step(action: "scroll", selector: selector)]).script(page: page(height: height, boxes: boxes)).script
        return script.scrolls.first?.offset.y
    }

    @Test func aScrollToAnElementLeavesAMarginAboveIt() throws {
        let expected = CGFloat(1200 - ScrollClip.Target.margin * 900)

        #expect(try scrollTop(of: "#pricing", at: 1200) == expected)
    }

    @Test func aScrollStopsAtTheTopAndTheBottomOfThePage() throws {
        #expect(try scrollTop(of: "#top", at: 100) == 0)
        // 3000 px of page under a 900 px viewport scrolls to 2100
        #expect(try scrollTop(of: "#footer", at: 2900) == 2100)
        #expect(try scrollTop(of: "#short", at: 500, height: 700) == 0)
    }

    @Test func aScrollToAPositionIsClampedToo() throws {
        let script = try plan([Step(action: "scroll", offset: 5000)]).script(page: page()).script

        #expect(script.scrolls.map(\.offset.y) == [2100])
    }

    @Test func aScrollToAnElementAimsAgainInTheTake() throws {
        let boxes = ["#pricing": PageInspection.Box(left: 0, top: 1200, width: 100, height: 50)]

        let script = try plan([Step(action: "scroll", selector: "#pricing")]).script(page: page(boxes: boxes)).script

        #expect(script.scrolls.first?.target == ScrollClip.Target(selector: "#pricing", placement: .top))
    }

    @Test func aScrollToAnElementThePageDoesntHaveFails() throws {
        let missing = try plan([Step(action: "scroll", selector: "#gone")])

        #expect(throws: AgentToolError.self) { try missing.script(page: page()) }
        #expect(throws: AgentToolError.self) { try missing.script(page: page(boxes: nil)) }
    }

    @Test func aClickOnAnElementThePageDoesntHaveFails() throws {
        #expect(throws: AgentToolError.self) { try plan([Step(action: "click", selector: "#gone")]).script(page: page()) }
    }

    @Test func aClickAimsAtTheElementsCentreWhereThePageIsScrolledToThen() throws {
        let boxes = ["#buy": PageInspection.Box(left: 100, top: 700, width: 200, height: 60)]
        // The scroll ends at 2 s; the click follows the gap later
        let steps = [Step(action: "scroll", offset: 500, start: 0.5, duration: 1.5), Step(action: "click", selector: "#buy")]

        let result = try plan(steps).script(page: page(boxes: boxes))

        let click = try #require(result.script.pointer.first)
        #expect(click.range == 2.8..<4.3)
        #expect(click.action == .click)
        #expect(click.target.selector == "#buy")
        #expect(click.target.point == CGPoint(x: 200, y: 230))
        #expect(result.warnings.isEmpty)
        let presses = result.script.presses(after: 0, through: 10)
        #expect(presses.map(\.time) == [2.8, 2.9])
        #expect(presses.map(\.isDown) == [true, false])
    }

    @Test func aCursorStepBringsItsElementIntoViewFirst() throws {
        let boxes = ["#plan": PageInspection.Box(left: 100, top: 1500, width: 200, height: 100)]

        let script = try plan([Step(action: "hover", selector: "#plan")]).script(page: page(boxes: boxes)).script

        // In the second before the hover, to a margin above the viewport's bottom: 1600 - 900 + 135
        let scroll = try #require(script.scrolls.first)
        #expect(scroll.range == 0..<1)
        #expect(scroll.target == ScrollClip.Target(selector: "#plan", placement: .intoView))
        #expect(scroll.offset.y == 835)
        #expect(script.pointer.first?.target.point == CGPoint(x: 200, y: 715))
    }

    @Test func anElementInViewStaysPut() throws {
        let boxes = ["#buy": PageInspection.Box(left: 100, top: 300, width: 200, height: 60)]

        let script = try plan([Step(action: "hover", selector: "#buy")]).script(page: page(boxes: boxes)).script

        #expect(script.scrolls.map(\.offset) == [.zero])
    }

    @Test func thereIsNoScrollIntoViewWithoutRoomForIt() throws {
        let boxes = ["#a": PageInspection.Box(left: 0, top: 100, width: 10, height: 10), "#b": PageInspection.Box(left: 0, top: 200, width: 10, height: 10)]
        let steps = [Step(action: "hover", selector: "#a", start: 0.1), Step(action: "hover", selector: "#b", start: 1.7)]

        let script = try plan(steps).script(page: page(boxes: boxes)).script

        // 0.1 s before the first, 0.1 s between them: neither has the 0.2 s a scroll needs
        #expect(script.scrolls.isEmpty)
    }

    @Test func aHoverBeforeTheScrollIsAimedWithoutIt() throws {
        let boxes = ["#buy": PageInspection.Box(left: 100, top: 700, width: 200, height: 60)]
        let steps = [Step(action: "hover", selector: "#buy", start: 0.5), Step(action: "scroll", offset: 500, start: 2)]

        let script = try plan(steps).script(page: page(boxes: boxes)).script

        #expect(script.pointer.first?.target.point == CGPoint(x: 200, y: 730))
    }

    @Test func anElementThePageDoesntHaveIsAimedAtTheMiddleAndReported() throws {
        let steps = [Step(action: "hover", selector: "#gone"), Step(action: "type", selector: "#gone", text: "hi"), Step(action: "hover", selector: "#also")]

        let result = try plan(steps).script(page: page())

        #expect(result.script.pointer.map(\.target.point) == Array(repeating: CGPoint(x: 720, y: 450), count: 3))
        #expect(result.warnings.count == 2)
        #expect(result.warnings.first?.hasPrefix("At 1.0 s no element matched \"#gone\"") == true)
        // The selector stays: the page may have it by the time of the take
        #expect(result.script.pointer.first?.target.selector == "#gone")
    }

    @Test func stepsAfterAClickAreAimedWhenTheTakeGetsThere() throws {
        let boxes = ["#plan-link": PageInspection.Box(left: 100, top: 100, width: 100, height: 20)]
        let steps = [
            Step(action: "click", selector: "#plan-link"), Step(action: "hover", selector: "#plan-hero", show: "#plan-hero"),
            Step(action: "scroll", selector: "#forecast")
        ]

        let result = try plan(steps).script(page: page(boxes: boxes))

        // On a page the click may open: no error, no warning, the middle until the take finds them
        #expect(result.warnings.isEmpty)
        #expect(result.script.pointer.last?.target.point == CGPoint(x: 720, y: 450))
        let scroll = try #require(result.script.scrolls.last)
        #expect(scroll.target == ScrollClip.Target(selector: "#forecast", placement: .top))
        #expect(scroll.offset == .zero)
    }

    @Test func theScriptCarriesThePlansSettings() throws {
        let request = RecordPageRequest(url: "example.com/x", viewport: "tablet", scale: 2, duration: 8, steps: [])

        let script = try request.plan().script(page: page()).script

        #expect(script.url?.absoluteString == "https://example.com/x")
        #expect(script.viewport == WebScript.Viewport.tablet.size)
        #expect(script.scale == 2)
        #expect(script.duration == 8)
    }

    @Test func selectorsAreDistinctAndInOrder() throws {
        let steps = [
            Step(action: "hover", selector: "#b", show: "#c"), Step(action: "click", selector: "#a"),
            Step(action: "scroll", selector: "#b"), Step(action: "scroll", offset: 5)
        ]

        #expect(try plan(steps).selectors == ["#b", "#c", "#a"])
    }

    @Test func aStepsShowReachesItsClip() throws {
        let boxes = ["#buy": PageInspection.Box(left: 100, top: 100, width: 200, height: 60), "#shot": PageInspection.Box(left: 0, top: 200, width: 600, height: 400)]

        let result = try plan([Step(action: "hover", selector: "#buy", show: " #shot ")]).script(page: page(boxes: boxes))

        #expect(result.script.pointer.first?.show == "#shot")
        #expect(result.warnings.isEmpty)
    }

    @Test func aShowThePageDoesntHaveIsReported() throws {
        let boxes = ["#buy": PageInspection.Box(left: 100, top: 100, width: 200, height: 60)]

        let result = try plan([Step(action: "hover", selector: "#buy", show: "#gone")]).script(page: page(boxes: boxes))

        #expect(result.warnings.count == 1)
        #expect(result.warnings.first?.contains("the shown element \"#gone\"") == true)
    }

    @Test func showIsCheckedAndOnlyForTheCursor() {
        #expect(throws: AgentToolError.self) { try plan([Step(action: "click", selector: "#a", show: " ")]) }
        #expect(throws: AgentToolError.self) { try plan([Step(action: "scroll", offset: 100, show: "#a")]) }
        #expect((try? plan([Step(action: "type", selector: "#a", show: "#form", text: "hi")])) != nil)
    }

    @Test func showDecodesFromTheToolsArguments() throws {
        let json = Data(##"{"url":"example.com","steps":[{"action":"click","selector":"#a","show":"#b"}]}"##.utf8)

        let request = try JSONDecoder().decode(RecordPageRequest.self, from: json)

        #expect(request.steps.first?.show == "#b")
    }

    @Test func aTypeStepTypesItsTextAndLastsAsLongAsIt() throws {
        let boxes = ["#q": PageInspection.Box(left: 100, top: 100, width: 300, height: 40)]
        let text = String(repeating: "x", count: 20)

        let script = try plan([Step(action: "type", selector: "#q", text: text)]).script(page: page(boxes: boxes)).script

        let clip = try #require(script.pointer.first)
        #expect(clip.action == .type)
        #expect(clip.text == text)
        #expect(abs((clip.range.upperBound - clip.range.lowerBound) - PointerClip.typingDuration(for: text)) < 1e-9)
    }

    @Test func textIsCheckedAndOnlyForTyping() {
        #expect(throws: AgentToolError.self) { try plan([Step(action: "type", selector: "#q")]) }
        #expect(throws: AgentToolError.self) { try plan([Step(action: "type", selector: "#q", text: "")]) }
        #expect(throws: AgentToolError.self) { try plan([Step(action: "type", selector: "#q", text: String(repeating: "x", count: 501))]) }
        #expect(throws: AgentToolError.self) { try plan([Step(action: "click", selector: "#q", text: "hi")]) }
        #expect(throws: AgentToolError.self) { try plan([Step(action: "scroll", offset: 10, text: "hi")]) }
        #expect(throws: AgentToolError.self) { try plan([Step(action: "type", text: "hi")]) }
    }
}
