//
//  RecordPageRequestTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

struct RecordPageRequestTests {

    private typealias Step = RecordPageRequest.Step

    private func request(
        url: String = "example.com", viewport: String? = nil, scale: Int? = nil, duration: Double? = nil, steps: [Step] = []
    ) -> RecordPageRequest {
        RecordPageRequest(url: url, viewport: viewport, scale: scale, duration: duration, steps: steps)
    }

    private func hover(_ selector: String? = "#a", start: Double? = nil, duration: Double? = nil) -> Step {
        Step(action: "hover", selector: selector, start: start, duration: duration)
    }

    private func click(_ selector: String? = "#a", start: Double? = nil, duration: Double? = nil) -> Step {
        Step(action: "click", selector: selector, start: start, duration: duration)
    }

    private func scroll(selector: String? = nil, y position: Double? = nil, start: Double? = nil, duration: Double? = nil) -> Step {
        Step(action: "scroll", selector: selector, offset: position, start: start, duration: duration)
    }

    /// What `plan()` says is wrong, or `nil` when the request is fine.
    private func problem(_ request: RecordPageRequest) -> String? {
        do {
            _ = try request.plan()
            return nil
        } catch {
            return error.errorDescription
        }
    }

    @Test func stepsAreSpacedAutomatically() throws {
        let plan = try request(steps: [hover("#a"), click("#b"), scroll(y: 500)]).plan()

        let first = RecordPlan.leadIn..<RecordPlan.leadIn + RecordPlan.pointerDuration
        let second = first.upperBound + RecordPlan.gap..<first.upperBound + RecordPlan.gap + RecordPlan.pointerDuration
        let third = second.upperBound + RecordPlan.gap..<second.upperBound + RecordPlan.gap + RecordPlan.scrollDuration
        let ranges: [Range<Double>] = plan.steps.map(\.range)
        #expect(ranges == [first, second, third])
        // The last step's end and a moment to finish
        #expect(plan.duration == third.upperBound + RecordPlan.tail)
    }

    @Test func defaultsAreTheDesktopAtTwiceTheSize() throws {
        let plan = try request(url: "example.com/pricing").plan()

        #expect(plan.url.absoluteString == "https://example.com/pricing")
        #expect(plan.viewport == WebScript.Viewport.desktop.size)
        #expect(plan.scale == 2)
    }

    @Test func explicitStartsAndDurationsAreKept() throws {
        let plan = try request(viewport: "phone", scale: 1, duration: 10, steps: [click("#a", start: 2, duration: 0.5), scroll(y: 100, duration: 3)]).plan()

        let ranges: [Range<Double>] = plan.steps.map(\.range)
        let scroll = 2.5 + RecordPlan.gap..<2.5 + RecordPlan.gap + 3
        #expect(ranges == [2.0..<2.5, scroll])
        #expect(plan.duration == 10)
        #expect(plan.scale == 1)
        #expect(plan.viewport == WebScript.Viewport.phone.size)
    }

    @Test func aStepAfterAnEarlierOneStartsAfterTheListsPreviousStep() throws {
        let plan = try request(steps: [click("#a", start: 5), hover("#b")]).plan()

        let starts: [Double] = plan.steps.map(\.range.lowerBound)
        #expect(starts == [5.0, 5 + RecordPlan.pointerDuration + RecordPlan.gap])
    }

    @Test func overlapsOnTheSameLaneNameBothSteps() {
        let cursor = problem(request(steps: [hover("#a", start: 1, duration: 2), click("#b", start: 2)]))
        let scrolls = problem(request(steps: [scroll(y: 1, start: 1, duration: 2), scroll(y: 2, start: 2)]))

        #expect(cursor?.contains("steps[1] overlaps steps[0] on the cursor lane") == true)
        #expect(scrolls?.contains("steps[1] overlaps steps[0] on the scroll lane") == true)
    }

    @Test func aHoverMayHappenWhileThePageScrolls() throws {
        let plan = try request(steps: [scroll(y: 900, start: 1, duration: 2), hover("#a", start: 1.5)]).plan()

        #expect(plan.steps.count == 2)
    }

    @Test func aStepMayStartWhereAnotherEnds() throws {
        let plan = try request(steps: [hover("#a", start: 1, duration: 1), hover("#b", start: 2)]).plan()

        #expect(plan.steps[1].range == 2.0..<2 + RecordPlan.pointerDuration)
    }

    @Test func badStepsAreExplained() {
        let cases: [(RecordPageRequest, String)] = [
            (request(steps: [hover(nil)]), "needs a selector"),
            (request(steps: [click("  ")]), "needs a selector"),
            (request(steps: [Step(action: "hover", selector: "#a", offset: 5)]), "scroll only"),
            (request(steps: [scroll()]), "either a selector or y"),
            (request(steps: [scroll(selector: "#a", y: 5)]), "either a selector or y"),
            (request(steps: [scroll(y: -1)]), "0 or more"),
            (request(steps: [Step(action: "drag", selector: "#a")]), "hover, click or scroll"),
            (request(steps: [hover(start: -1)]), "start"),
            (request(steps: [hover(duration: 0.1)]), "at least 0.2"),
            (request(steps: [scroll(y: 1, duration: 0.1)]), "at least 0.2")
        ]
        for (bad, reason) in cases {
            let message = problem(bad)
            #expect(message?.contains(reason) == true, "\(message ?? "no problem") should mention \(reason)")
            #expect(message?.contains("steps[0]") == true)
        }
    }

    @Test func badSettingsAreExplained() {
        #expect(problem(request(url: "not a page")) != nil)
        #expect(problem(request(url: "ftp://example.com")) != nil)
        #expect(problem(request(viewport: "watch"))?.contains("desktop") == true)
        #expect(problem(request(scale: 3))?.contains("1 or 2") == true)
    }

    @Test func theDurationHasToHoldTheStepsAndStayUnderTheMaximum() {
        #expect(problem(request(duration: 1, steps: [hover()]))?.contains("at least 2.5") == true)
        #expect(problem(request(duration: 130))?.contains("120") == true)
        #expect(problem(request(steps: [scroll(y: 1, start: 119, duration: 1.5)]))?.contains("120") == true)
        #expect(problem(request(duration: 120, steps: [hover()])) == nil)
    }

    @Test func noStepsMakeAShortTake() throws {
        let plan = try request().plan()

        #expect(plan.steps.isEmpty)
        #expect(plan.duration == max(RecordPlan.tail, WebScript.minimumDuration))
    }

    // MARK: - From a take

    @Test func aTakesScriptBecomesTheArgumentsThatRecordItAgain() throws {
        var script = WebScript()
        script.url = URL(string: "https://example.com/pricing")
        script.viewport = WebScript.Viewport.phone.size
        script.scale = 1
        script.duration = 12
        script.pointer = [
            PointerClip(range: 1..<2.5, action: .hover, target: WebTarget(selector: "#plans", point: .zero)),
            PointerClip(range: 6..<7.5, action: .click, target: WebTarget(selector: "#buy", point: .zero)),
            PointerClip(range: 8..<9, action: .hover, target: WebTarget(point: .zero))
        ]
        script.scrolls = [
            ScrollClip(range: 3..<5, offset: CGPoint(x: 0, y: 1200), target: .init(selector: "#faq", placement: .top)),
            ScrollClip(range: 5.5..<6, offset: CGPoint(x: 0, y: 1300), target: .init(selector: "#buy", placement: .intoView)),
            ScrollClip(range: 9..<11, offset: CGPoint(x: 0, y: 0.30000000000000004))
        ]

        let request = RecordPageRequest(script: script)

        #expect(request.url == "https://example.com/pricing")
        #expect(request.viewport == "phone")
        #expect(request.scale == 1)
        #expect(request.duration == 12)
        // Reco's own scroll into view and the clip without a selector are left out
        #expect(request.steps == [
            Step(action: "hover", selector: "#plans", start: 1, duration: 1.5),
            Step(action: "scroll", selector: "#faq", start: 3, duration: 2),
            Step(action: "click", selector: "#buy", start: 6, duration: 1.5),
            Step(action: "scroll", offset: 0.3, start: 9, duration: 2)
        ])
        // Which records the same steps again
        let plan = try request.plan()
        #expect(plan.steps.map(\.range) == [1..<2.5, 3..<5, 6..<7.5, 9..<11])
    }
}
