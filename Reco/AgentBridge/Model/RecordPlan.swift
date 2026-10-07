//
//  RecordPlan.swift
//  Reco
//

import CoreGraphics
import Foundation

/// What an agent asked `record_page` to do, validated and timed, before the page has been looked
/// at. ``script(page:)`` aims it at the page's elements.
nonisolated struct RecordPlan: Equatable, Sendable {
    var url: URL
    var viewport: CGSize
    var scale: Int
    var duration: Double
    var steps: [TimedStep]

    /// One step on its lane, from `steps[index]` of the request.
    nonisolated struct TimedStep: Equatable, Sendable {
        var index: Int

        /// `nil` for a scroll.
        var action: PointerClip.Action?
        var selector: String?

        /// Where a scroll goes, in CSS pixels from the page's top, when it has no selector.
        var offset: Double?
        var range: Range<Double>

        /// The element the video zooms on during a hover, click or type.
        var show: String?

        /// What a type step types.
        var text: String?
    }

    /// The first step starts this many seconds in, so the page shows before anything moves.
    static let leadIn = 1.0

    /// The pause after a step before the next one that gives no start, which the cursor spends
    /// travelling: Fitts's law puts a mouse's 800 px move to a 40 px target at about 0.96 s
    /// (MacKenzie 1992), and the travel takes at most ``WebScript/maximumTravel``.
    static let gap = 0.8

    /// How long a hover or click lasts when it gives no duration: long enough to see what it shows.
    static let pointerDuration = 1.5

    /// How long a scroll lasts when it gives no duration.
    static let scrollDuration = 2.0

    /// How long the take runs on after its last step.
    static let tail = 1.5

    /// The longest a scroll that brings a cursor step's element into view takes.
    static let intoViewDuration = 1.0

    /// The page as the agent will see it, to inspect before the take can be aimed.
    var inspectionScript: WebScript {
        var script = WebScript()
        script.url = url
        script.viewport = viewport
        return script
    }

    /// The distinct selectors the steps use, in order, to find their boxes.
    var selectors: [String] {
        var seen = Set<String>()
        return steps.flatMap { [$0.selector, $0.show].compactMap(\.self) }.filter { seen.insert($0).inserted }
    }

    /// The take for `page`, and what the page lacks that the steps on it need, as warnings for the
    /// agent. A click or scroll on it whose element it doesn't have is an error.
    ///
    /// Scrolls to an element aim at it again when they start in the take, and each cursor step gets
    /// a scroll that brings its element into view first, if the Scroll lane has room before it: a
    /// scroll the agent planned may stop short, and a page's layout may shift. Both stay put when the
    /// element is in view already. Steps after a click may be on another page, so their elements are
    /// found when the take gets there.
    func script(page: PageInspection) throws(AgentToolError) -> (script: WebScript, warnings: [String]) {
        var script = inspectionScript
        script.scale = scale
        script.duration = duration
        var issues = WebTakeIssues(viewport: viewport)
        let ordered = steps.sorted { $0.range.lowerBound < $1.range.lowerBound }
        // Steps after a click may be on another page, whose elements the take finds when it gets there
        let isOnPage = { (step: TimedStep) in !ordered.contains { $0.action == .click && $0.range.lowerBound < step.range.lowerBound } }

        for step in ordered where step.action == nil {
            let clip = try scrollClip(for: step, from: script.scrollOffset(at: step.range.lowerBound), isOnPage: isOnPage(step), on: page)
            script.scrolls = script.scrolls.inserting(clip)
        }

        var previousEnd = 0.0
        for step in ordered {
            guard let action = step.action, let selector = step.selector else { continue }
            let rect = isOnPage(step) ? page.boxes?[selector]?.rect : nil
            insertScrollIntoView(before: step, after: previousEnd, showing: rect, on: page, in: &script)
            previousEnd = step.range.upperBound

            var point = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
            if let rect {
                // The viewport's point, not the page's: where the element is once the scrolls before it are done
                let scrolled = script.scrollOffset(at: step.range.lowerBound)
                point = CGPoint(x: rect.midX - scrolled.x, y: rect.midY - scrolled.y)
            } else if isOnPage(step) {
                // A click aimed at nothing would land on whatever is there, and may open another page
                guard action != .click else {
                    throw .invalidArgument("steps[\(step.index)]: no element matches \"\(selector)\" on the page, so there's nothing to click. "
                        + "Use a selector from inspect_page.")
                }
                issues.check(selector, at: step.range.lowerBound, frame: nil, cover: nil)
            }
            if let show = step.show, isOnPage(step), page.boxes?[show] == nil {
                _ = issues.shown(show, at: step.range.lowerBound, frame: nil)
            }
            let target = WebTarget(selector: selector, point: point)
            script.pointer = script.pointer.inserting(PointerClip(range: step.range, action: action, target: target, text: step.text, show: step.show))
        }
        return (script, issues.messages)
    }

    /// Scroll `step`'s clip, from `current`: to its element or position on `page`, kept inside it, when
    /// `isOnPage`; otherwise the take finds where when the clip starts.
    private func scrollClip(for step: TimedStep, from current: CGPoint, isOnPage: Bool, on page: PageInspection) throws(AgentToolError) -> ScrollClip {
        var clip = ScrollClip(range: step.range, offset: CGPoint(x: 0, y: step.offset ?? 0))
        if let selector = step.selector {
            let target = ScrollClip.Target(selector: selector, placement: .top)
            clip.target = target
            guard isOnPage else {
                clip.offset = current
                return clip
            }
            guard let rect = page.boxes?[selector]?.rect else {
                throw .invalidArgument("steps[\(step.index)]: no element matches \"\(selector)\" on the page. Use a selector from inspect_page.")
            }
            clip.offset = target.offset(showing: rect.offsetBy(dx: -current.x, dy: -current.y), from: current, viewport: viewport, pageHeight: page.pageHeight)
        }
        if isOnPage {
            clip.offset.y = min(max(clip.offset.y, 0), max(page.pageHeight - viewport.height, 0))
        }
        return clip
    }

    /// Adds a scroll bringing the element of cursor `step` into view as the step starts, after
    /// `earliest` and the scroll before; none when a scroll is going on then or there isn't room.
    /// `rect` is the element's box in the page when it's on the page inspected.
    private func insertScrollIntoView(before step: TimedStep, after earliest: Double, showing rect: CGRect?, on page: PageInspection, in script: inout WebScript) {
        let time = step.range.lowerBound
        guard let selector = step.selector, !script.scrolls.contains(where: { $0.range.lowerBound < time && $0.range.upperBound > time }) else { return }
        let previous = script.scrolls.last { $0.range.upperBound <= time }?.range.upperBound ?? 0
        let start = max(previous, earliest, time - Self.intoViewDuration)
        guard time - start >= ScrollClip.minimumDuration else { return }
        let target = ScrollClip.Target(selector: selector, placement: .intoView)
        let current = script.scrollOffset(at: start)
        var offset = current
        if let rect {
            offset = target.offset(showing: rect.offsetBy(dx: -current.x, dy: -current.y), from: current, viewport: viewport, pageHeight: page.pageHeight)
        }
        script.scrolls = script.scrolls.inserting(ScrollClip(range: start..<time, offset: offset, target: target))
    }
}
