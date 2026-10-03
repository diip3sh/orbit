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
        let expected = CGFloat(1200 - RecordPlan.scrollMargin * 900)

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

    @Test func aScrollToAnElementThePageDoesntHaveFails() throws {
        let missing = try plan([Step(action: "scroll", selector: "#gone")])

        #expect(throws: AgentToolError.self) { try missing.script(page: page()) }
        #expect(throws: AgentToolError.self) { try missing.script(page: page(boxes: nil)) }
    }

    @Test func aClickAimsAtTheElementsCentreWhereThePageIsScrolledToThen() throws {
        let boxes = ["#buy": PageInspection.Box(left: 100, top: 700, width: 200, height: 60)]
        // The scroll ends at 2 s; the click follows half a second later
        let steps = [Step(action: "scroll", offset: 500, start: 0.5, duration: 1.5), Step(action: "click", selector: "#buy")]

        let result = try plan(steps).script(page: page(boxes: boxes))

        let click = try #require(result.script.pointer.first)
        #expect(click.range == 2.5..<3.5)
        #expect(click.action == .click)
        #expect(click.target.selector == "#buy")
        #expect(click.target.point == CGPoint(x: 200, y: 230))
        #expect(result.unmatched.isEmpty)
        let presses = result.script.presses(after: 0, through: 10)
        #expect(presses.map(\.time) == [2.5, 2.6])
        #expect(presses.map(\.isDown) == [true, false])
    }

    @Test func aHoverBeforeTheScrollIsAimedWithoutIt() throws {
        let boxes = ["#buy": PageInspection.Box(left: 100, top: 700, width: 200, height: 60)]
        let steps = [Step(action: "hover", selector: "#buy", start: 0.5), Step(action: "scroll", offset: 500, start: 2)]

        let script = try plan(steps).script(page: page(boxes: boxes)).script

        #expect(script.pointer.first?.target.point == CGPoint(x: 200, y: 730))
    }

    @Test func anElementThePageDoesntHaveIsAimedAtTheMiddleAndReported() throws {
        let steps = [Step(action: "hover", selector: "#gone"), Step(action: "click", selector: "#gone"), Step(action: "hover", selector: "#also")]

        let result = try plan(steps).script(page: page())

        #expect(result.script.pointer.map(\.target.point) == Array(repeating: CGPoint(x: 720, y: 450), count: 3))
        #expect(result.unmatched == ["#gone", "#also"])
        // The selector stays: the page may have it by the time of the take
        #expect(result.script.pointer.first?.target.selector == "#gone")
    }

    @Test func theScriptCarriesThePlansSettings() throws {
        let request = RecordPageRequest(url: "example.com/x", viewport: "tablet", scale: 1, duration: 8, steps: [])

        let script = try request.plan().script(page: page()).script

        #expect(script.url?.absoluteString == "https://example.com/x")
        #expect(script.viewport == WebScript.Viewport.tablet.size)
        #expect(script.scale == 1)
        #expect(script.duration == 8)
    }

    @Test func selectorsAreDistinctAndInOrder() throws {
        let steps = [
            Step(action: "hover", selector: "#b"), Step(action: "click", selector: "#a"),
            Step(action: "scroll", selector: "#b"), Step(action: "scroll", offset: 5)
        ]

        #expect(try plan(steps).selectors == ["#b", "#a"])
    }

    @Test func aStepsZoomReachesItsClip() throws {
        let boxes = ["#buy": PageInspection.Box(left: 100, top: 100, width: 200, height: 60)]

        let script = try plan([Step(action: "hover", selector: "#buy", zoom: 2)]).script(page: page(boxes: boxes)).script

        #expect(script.pointer.first?.zoom == 2)
    }

    @Test func zoomIsCheckedAndOnlyForTheCursor() {
        #expect(throws: AgentToolError.self) { try plan([Step(action: "click", selector: "#a", zoom: 10)]) }
        #expect(throws: AgentToolError.self) { try plan([Step(action: "click", selector: "#a", zoom: 1)]) }
        #expect(throws: AgentToolError.self) { try plan([Step(action: "scroll", offset: 100, zoom: 2)]) }
        #expect((try? plan([Step(action: "click", selector: "#a", zoom: 4)])) != nil)
    }

    @Test func zoomDecodesFromTheToolsArguments() throws {
        let json = Data(##"{"url":"example.com","steps":[{"action":"click","selector":"#a","zoom":1.5}]}"##.utf8)

        let request = try JSONDecoder().decode(RecordPageRequest.self, from: json)

        #expect(request.steps.first?.zoom == 1.5)
    }

    @Test func aTypeStepTypesItsTextAndLastsAsLongAsIt() throws {
        let boxes = ["#q": PageInspection.Box(left: 100, top: 100, width: 300, height: 40)]
        let text = String(repeating: "x", count: 20)

        let script = try plan([Step(action: "type", selector: "#q", zoom: 2, text: text)]).script(page: page(boxes: boxes)).script

        let clip = try #require(script.pointer.first)
        #expect(clip.action == .type)
        #expect(clip.text == text)
        #expect(clip.zoom == 2)
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

