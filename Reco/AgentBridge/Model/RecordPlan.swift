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
    static let leadIn = 0.5

    /// The pause after a step before the next one that gives no start.
    static let gap = 0.5

    /// How long the take runs on after its last step.
    static let tail = 1.0

    /// The share of the viewport's height left above an element a scroll brings up. A guess that
    /// clears typical sticky headers; not measured.
    static let scrollMargin = 0.15

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
    /// middle of the viewport. A scroll to a selector that matched nothing is an error.
    func script(page: PageInspection) throws(AgentToolError) -> (script: WebScript, unmatched: [String]) {
        var script = inspectionScript
        script.scale = scale
        script.duration = duration

        let furthest = max(0, page.pageHeight - viewport.height)
        for step in steps where step.action == nil {
            var top = step.offset ?? 0
            if let selector = step.selector {
                guard let box = page.boxes?[selector] else {
                    throw .invalidArgument("steps[\(step.index)]: no element matches \"\(selector)\" on the page. Use a selector from inspect_page.")
                }
                top = box.top - Self.scrollMargin * viewport.height
            }
            script.scrolls = script.scrolls.inserting(ScrollClip(range: step.range, offset: CGPoint(x: 0, y: min(max(top, 0), furthest))))
        }

        var unmatched: [String] = []
        let centre = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        for step in steps {
            guard let action = step.action, let selector = step.selector else { continue }
            var point = centre
            if let box = page.boxes?[selector]?.rect {
                // The viewport's point, not the page's: where the element is once the scrolls before it are done
                let scrolled = script.scrollOffset(at: step.range.lowerBound)
                point = CGPoint(x: box.midX - scrolled.x, y: box.midY - scrolled.y)
            } else if !unmatched.contains(selector) {
                unmatched.append(selector)
            }
            let target = WebTarget(selector: selector, point: point)
            script.pointer = script.pointer.inserting(PointerClip(range: step.range, action: action, target: target))
        }
        return (script, unmatched)
    }
}
