//
//  RecordPageRequest.swift
//  Reco
//

import CoreGraphics
import Foundation

/// The arguments of the `record_page` tool: a page and what the cursor and scrolling do on it.
nonisolated struct RecordPageRequest: Codable, Equatable, Sendable {
    var url: String
    var viewport: String?
    var scale: Int?
    var duration: Double?
    var steps: [Step]

    nonisolated struct Step: Codable, Equatable, Sendable {

        /// `hover`, `click`, `type` or `scroll`.
        var action: String
        var selector: String?

        /// Where a scroll goes: CSS pixels from the page's top. Its JSON key is `y`.
        var offset: Double?
        var start: Double?
        var duration: Double?

        /// Hover, click and type only: a CSS selector for the element the video zooms on during the step.
        var show: String?

        /// Type only: what to type into the field.
        var text: String?

        // swiftlint:disable:next nesting - the schema's key is y, too short a name for a property
        private enum CodingKeys: String, CodingKey {
            case offset = "y"
            case action, selector, start, duration, show, text
        }
    }

    /// The most a type step may type: a form field's worth, not a document.
    static let maximumTextLength = 500

    /// Times the steps and checks everything that doesn't need the page.
    func plan() throws(AgentToolError) -> RecordPlan {
        let url = try Self.pageURL(url)
        let viewport = try Self.viewportSize(viewport)
        // 1×, since a minute of a heavy page takes 15 minutes and more to render at 2×
        let scale = scale ?? 1
        guard [1, 2].contains(scale) else { throw .invalidArgument("scale must be 1 or 2.") }

        var timed: [RecordPlan.TimedStep] = []
        var previousEnd: Double?
        for (index, step) in steps.enumerated() {
            let timedStep = try timing(of: step, at: index, after: previousEnd)
            // Cursor clips can't overlap each other, nor scrolls, but a hover may happen while a page scrolls
            if let clash = timed.first(where: { ($0.action == nil) == (timedStep.action == nil) && $0.range.overlaps(timedStep.range) }) {
                let lane = timedStep.action == nil ? "scroll" : "cursor"
                throw .invalidArgument("steps[\(index)] overlaps steps[\(clash.index)] on the \(lane) lane. Give it a later start.")
            }
            timed.append(timedStep)
            previousEnd = timedStep.range.upperBound
        }

        let lastEnd = timed.map(\.range.upperBound).max() ?? 0
        var duration = max(lastEnd + RecordPlan.tail, WebScript.minimumDuration)
        if let requested = self.duration {
            guard requested >= lastEnd else { throw .invalidArgument("duration must be at least \(lastEnd) s, when the last step ends.") }
            duration = requested
        }
        guard duration <= WebScript.maximumDuration else {
            throw .invalidArgument("The take would last \(duration) s; the most is \(WebScript.maximumDuration) s.")
        }
        return RecordPlan(url: url, viewport: viewport, scale: scale, duration: duration, steps: timed)
    }

    private func timing(of step: Step, at index: Int, after previousEnd: Double?) throws(AgentToolError) -> RecordPlan.TimedStep {
        let name = "steps[\(index)]"
        let selector = step.selector?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSelector = !(selector ?? "").isEmpty
        let action: PointerClip.Action?
        let minimum: Double
        let fallback: Double
        switch step.action {
        case "hover", "click", "type":
            guard hasSelector else { throw .invalidArgument("\(name): \(step.action) needs a selector from inspect_page.") }
            guard step.offset == nil else { throw .invalidArgument("\(name): y is for scroll only.") }
            if let show = step.show, show.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw .invalidArgument("\(name): show needs a selector from inspect_page.")
            }
            if step.action == "type" {
                guard let text = step.text, !text.isEmpty, text.count <= Self.maximumTextLength else {
                    throw .invalidArgument("\(name): type needs text, at most \(Self.maximumTextLength) characters.")
                }
            } else if step.text != nil {
                throw .invalidArgument("\(name): text is for type only.")
            }
            action = PointerClip.Action(rawValue: step.action)
            minimum = PointerClip.minimumDuration
            fallback = step.text.map(PointerClip.typingDuration(for:)) ?? RecordPlan.pointerDuration
        case "scroll":
            guard hasSelector != (step.offset != nil) else { throw .invalidArgument("\(name): scroll needs either a selector or y, not both.") }
            if let offset = step.offset, offset < 0 {
                throw .invalidArgument("\(name): y must be 0 or more.")
            }
            guard step.show == nil, step.text == nil else { throw .invalidArgument("\(name): show and text aren't for scroll.") }
            action = nil
            minimum = ScrollClip.minimumDuration
            fallback = RecordPlan.scrollDuration
        default:
            throw .invalidArgument("\(name): action must be hover, click, type or scroll.")
        }

        let start = step.start ?? previousEnd.map { $0 + RecordPlan.gap } ?? RecordPlan.leadIn
        guard start >= 0 else { throw .invalidArgument("\(name): start must be 0 or more.") }
        let length = step.duration ?? fallback
        guard length >= minimum else { throw .invalidArgument("\(name): duration must be at least \(minimum) s.") }
        return RecordPlan.TimedStep(
            index: index, action: action, selector: hasSelector ? selector : nil, offset: step.offset, range: start..<start + length,
            show: step.show?.trimmingCharacters(in: .whitespacesAndNewlines), text: step.text
        )
    }

    // MARK: - Shared with inspect_page

    static func pageURL(_ text: String) throws(AgentToolError) -> URL {
        guard let url = WebScript.url(from: text) else {
            throw .invalidArgument("url must be a web address, like https://example.com/pricing.")
        }
        return url
    }

    static func viewportSize(_ name: String?) throws(AgentToolError) -> CGSize {
        guard let name else { return WebScript.Viewport.desktop.size }
        guard let viewport = WebScript.Viewport(rawValue: name) else {
            throw .invalidArgument("viewport must be one of: \(WebScript.Viewport.allCases.map(\.rawValue).joined(separator: ", ")).")
        }
        return viewport.size
    }
}
