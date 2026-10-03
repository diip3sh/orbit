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

        /// What a `type` step types into its element after clicking it.
        var text: String?

        /// The element the video zooms on during a cursor step, when the agent chooses the zooms.
        var show: String?

        // swiftlint:disable:next nesting - the schema's key is y, too short a name for a property
        private enum CodingKeys: String, CodingKey {
            case offset = "y"
            case action, selector, start, duration, text, show
        }
    }

    /// Times the steps and checks everything that doesn't need the page.
    func plan() throws(AgentToolError) -> RecordPlan {
        let url = try Self.pageURL(url)
        let viewport = try Self.viewportSize(viewport)
        let scale = scale ?? 2
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
        let show = step.show?.trimmingCharacters(in: .whitespacesAndNewlines)
        let shows = !(show ?? "").isEmpty
        let action: PointerClip.Action?
        let minimum: Double
        var fallback: Double
        try Self.checkFields(of: step, named: name)
        switch step.action {
        case "hover", "click", "type":
            guard hasSelector else { throw .invalidArgument("\(name): \(step.action) needs a selector from inspect_page.") }
            // Typing is a click on the field, then its keys
            action = step.action == "hover" ? .hover : .click
            minimum = PointerClip.minimumDuration
            fallback = step.text.map(PointerClip.typingDuration) ?? RecordPlan.pointerDuration
        case "scroll":
            guard hasSelector != (step.offset != nil) else { throw .invalidArgument("\(name): scroll needs either a selector or y, not both.") }
            if let offset = step.offset, offset < 0 {
                throw .invalidArgument("\(name): y must be 0 or more.")
            }
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
            text: step.text, show: shows ? show : nil
        )
    }

    /// The fields that go with one action only: text with type, y with scroll, show with the cursor actions.
    private static func checkFields(of step: Step, named name: String) throws(AgentToolError) {
        guard (step.action == "type") == (step.text?.isEmpty == false) else {
            throw .invalidArgument(step.action == "type" ? "\(name): type needs the text to type." : "\(name): text is for type only.")
        }
        if ["hover", "click", "type"].contains(step.action), step.offset != nil {
            throw .invalidArgument("\(name): y is for scroll only.")
        }
        if step.action == "scroll", !(step.show ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw .invalidArgument("\(name): show is for hover, click and type only.")
        }
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

// MARK: - From a take

nonisolated extension RecordPageRequest {

    /// The arguments that record `script` again, for an agent to change (spec 0008). Scrolls Reco
    /// added to bring a cursor's target into view are left out, since it adds them again, and so
    /// are cursor clips without a selector, which `record_page` can't aim.
    init(script: WebScript) {
        let pointer = script.pointer.compactMap { clip in
            clip.target.selector.map { selector in
                Step(
                    action: clip.text == nil ? clip.action.rawValue : "type", selector: selector,
                    start: Self.rounded(clip.range.lowerBound), duration: Self.rounded(clip.range.upperBound - clip.range.lowerBound),
                    text: clip.text, show: clip.show
                )
            }
        }
        let scrolls = script.scrolls.filter { $0.target?.placement != .intoView }.map { clip in
            Step(
                action: "scroll", selector: clip.target?.selector, offset: clip.target == nil ? Self.rounded(clip.offset.y) : nil,
                start: Self.rounded(clip.range.lowerBound), duration: Self.rounded(clip.range.upperBound - clip.range.lowerBound)
            )
        }
        self.init(
            url: script.url?.absoluteString ?? "",
            viewport: WebScript.Viewport.allCases.first { $0.size == script.viewport }?.rawValue,
            scale: script.scale,
            duration: Self.rounded(script.duration),
            steps: (pointer + scrolls).sorted { ($0.start ?? 0) < ($1.start ?? 0) }
        )
    }

    /// To the hundredth of a second or pixel, so the agent reads 2.5 rather than 2.4999999999999996.
    private static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
