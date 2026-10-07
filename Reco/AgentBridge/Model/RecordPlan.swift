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
    }

    /// The first step starts this many seconds in, so the page shows before anything moves.
    static let leadIn = 1.0

    /// The pause after a step before the next one that gives no start, which the cursor spends
    /// travelling: Fitts's law puts a mouse's 800 px move to a 40 px target at about 0.96 s
    /// (MacKenzie 1992), and the travel takes at most ``WebScript/maximumTravel``.
    static let gap = 0.8

    /// How long a hover or click lasts when it gives no duration: long enough to read what it shows.
    static let pointerDuration = 1.5

    /// How long a scroll lasts when it gives no duration.
    static let scrollDuration = 2.0

    /// How long the take runs on after its last step.
    static let tail = 1.5

    /// The longest a scroll that brings a cursor's target into view takes.
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
        return steps.compactMap(\.selector).filter { seen.insert($0).inserted }
    }

    /// The take for `page`, and the selectors that matched nothing: their cursor clips aim at the
    /// middle of the viewport.
    ///
    /// Scrolls to an element aim at it again when they start in the take, and each cursor clip gets
    /// a scroll that brings its element into view first, if the Scroll lane has room before it: a
    /// scroll the agent planned may stop short, and a page's layout may shift. Both stay put when
    /// the element is in view already.
    func script(page: PageInspection) throws(AgentToolError) -> (script: WebScript, unmatched: [String]) {
        var script = inspectionScript
        script.scale = scale
        script.duration = duration
        let hasClick = { (step: TimedStep) in steps.contains { $0.action == .click && $0.range.lowerBound < step.range.lowerBound } }

        for step in steps.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) where step.action == nil {
            let current = script.scrollOffset(at: step.range.lowerBound)
            var clip = ScrollClip(range: step.range, offset: CGPoint(x: 0, y: step.offset ?? 0))
            if let selector = step.selector {
                let target = ScrollClip.Target(selector: selector, placement: .top)
                clip.target = target
                if let box = page.boxes?[selector] {
                    clip.offset = target.offset(showing: box.rect.offsetBy(dx: -current.x, dy: -current.y), from: current, viewport: viewport, pageHeight: page.pageHeight)
                } else if hasClick(step) {
                    // On a page an earlier click opens, found when the scroll starts
                    clip.offset = current
                } else {
                    throw .invalidArgument("steps[\(step.index)]: no element matches \"\(selector)\" on the page. Use a selector from inspect_page.")
                }
            }
            clip.offset.y = min(max(clip.offset.y, 0), max(page.pageHeight - viewport.height, 0))
            script.scrolls = script.scrolls.inserting(clip)
        }

        var unmatched: [String] = []
        let centre = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        var previousEnd = 0.0
        for step in steps.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
            guard let action = step.action, let selector = step.selector else { continue }
            let box = page.boxes?[selector]?.rect
            insertScrollIntoView(before: step, after: previousEnd, on: page, in: &script)
            previousEnd = step.range.upperBound

            var point = centre
            if let box {
                // The viewport's point, not the page's: where the element is once the scrolls before it are done
                let scrolled = script.scrollOffset(at: step.range.lowerBound)
                point = CGPoint(x: box.midX - scrolled.x, y: box.midY - scrolled.y)
            } else if action == .click, !hasClick(step) {
                // A click aimed at nothing would land on whatever is there, and may open another page
                throw .invalidArgument("steps[\(step.index)]: no element matches \"\(selector)\" on the page, so there's nothing to click. Use a selector from inspect_page.")
            } else if !unmatched.contains(selector) {
                unmatched.append(selector)
            }
            let target = WebTarget(selector: selector, point: point)
            script.pointer = script.pointer.inserting(PointerClip(range: step.range, action: action, target: target))
        }
        return (script, unmatched)
    }

    /// Adds a scroll bringing the element of cursor `step` into view as the step starts, after
    /// `earliest` and the scroll before; none when a scroll is going on then or there isn't room.
    private func insertScrollIntoView(before step: TimedStep, after earliest: Double, on page: PageInspection, in script: inout WebScript) {
        let time = step.range.lowerBound
        guard let selector = step.selector, !script.scrolls.contains(where: { $0.range.lowerBound < time && $0.range.upperBound > time }) else { return }
        let previous = script.scrolls.last { $0.range.upperBound <= time }?.range.upperBound ?? 0
        let start = max(previous, earliest, time - Self.intoViewDuration)
        guard time - start >= ScrollClip.minimumDuration else { return }
        let target = ScrollClip.Target(selector: selector, placement: .intoView)
        let current = script.scrollOffset(at: start)
        let offset = page.boxes?[selector].map { box in
            target.offset(showing: box.rect.offsetBy(dx: -current.x, dy: -current.y), from: current, viewport: viewport, pageHeight: page.pageHeight)
        } ?? current
        script.scrolls = script.scrolls.inserting(ScrollClip(range: start..<time, offset: offset, target: target))
    }
}
