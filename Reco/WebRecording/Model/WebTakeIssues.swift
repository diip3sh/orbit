//
//  WebTakeIssues.swift
//  Reco
//

import CoreGraphics
import Foundation

/// What went wrong on the page during a take, in words for the agent that wrote the steps, so it can
/// change them and record again (spec 0008). Each cursor target is checked where its clip starts,
/// the way Playwright checks an action's target: on the page, in view, and not covered.
nonisolated struct WebTakeIssues: Sendable {

    let viewport: CGSize

    /// One per selector and kind of problem, in the order they happened.
    private(set) var messages: [String] = []
    private var reported = Set<String>()

    init(viewport: CGSize) {
        self.viewport = viewport
    }

    /// Checks the element `selector` matched, `frame` in viewport CSS pixels or `nil` for none, when
    /// the cursor arrives at `time`; `cover` describes what the page hit-tests at the cursor instead.
    mutating func check(_ selector: String, at time: Double, frame: CGRect?, cover: String?) {
        guard let frame else {
            return report("missing", selector, "At \(Self.seconds(time)) no element matched \"\(selector)\", so the cursor went to the "
                + "middle of the view. Use a selector from inspect_page of the page shown then.")
        }
        let point = CGPoint(x: frame.midX, y: frame.midY)
        guard CGRect(origin: .zero, size: viewport).contains(point) else {
            return report("outside", selector, "At \(Self.seconds(time)) \"\(selector)\" was outside the view (its middle at x \(Int(point.x)), "
                + "y \(Int(point.y)) of \(Int(viewport.width))×\(Int(viewport.height))), so the cursor stopped at the edge. Scroll to it "
                + "first, or pick an element in view.")
        }
        if let cover {
            report("covered", selector, "At \(Self.seconds(time)) \(cover) covered \"\(selector)\" where the cursor pointed. A menu an "
                + "earlier hover opened stays open while the cursor is over it: hover something outside it first, or leave more time.")
        }
    }

    /// A click at `time` was left out: nothing matched `selector`.
    mutating func skippedClick(_ selector: String, at time: Double) {
        report("click", selector, "At \(Self.seconds(time)) no element matched \"\(selector)\", so its click was left out. Use a selector "
            + "from inspect_page of the page shown then.")
    }

    /// A scroll at `time` found nothing matching `selector`, so the page didn't move.
    mutating func notFound(_ selector: String, at time: Double) {
        report("scroll", selector, "At \(Self.seconds(time)) the scroll found no element matching \"\(selector)\", so the page didn't move. "
            + "Scroll with y instead, or use a selector from inspect_page of the page shown then.")
    }

    private mutating func report(_ kind: String, _ selector: String, _ message: String) {
        guard reported.insert(kind + " " + selector).inserted else { return }
        messages.append(message)
    }

    /// "12.5 s", whatever the user's locale: it's read by an agent.
    private static func seconds(_ time: Double) -> String {
        time.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "en_US_POSIX"))) + " s"
    }
}
