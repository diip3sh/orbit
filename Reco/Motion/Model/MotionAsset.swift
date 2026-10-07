//
//  MotionAsset.swift
//  Reco
//

import CoreGraphics
import Foundation

/// UI lifted from a web page: the element `selector` matches on the page at `url`, laid out at
/// `viewport` CSS pixels. Captured into the bundle when a plan first needs it (``UILiftCache``).
///
/// Without `steps` it's a still, lifted at the scale it's shown, so `ui` layers stay sharp however
/// far the camera pushes in. With them it's live: a take of the page (the steps of `record_page`:
/// hover, click, type, scroll) cropped to the element's box where the page first shows it, played
/// from the start of each scene that shows it, with its cursor.
nonisolated struct MotionAsset: Equatable, Sendable, Identifiable {
    var id: String
    var url: URL
    var selector: String
    var viewport = CGSize(width: 1440, height: 900)
    var steps: [RecordPageRequest.Step]?

    /// Selectors hidden on the page first, like a cookie banner over a live take's element.
    var hide: [String]?

    /// A live take's length in seconds; when left out, as `record_page` times it.
    var duration: Double?

    /// Whether a still is shown on glass (spec 0012, L0): lifted bare, without its own background,
    /// border or shadow, on a panel of dark glass in its shape, lit as its shot is.
    var glass: Bool?

    /// Whether a still is lifted bare without glass: its content alone, without its own background or
    /// the page's behind it, set straight on the ground (a docs page's heading and text over satin).
    var bare: Bool?

    /// Whether it's lifted without any background, its own or the page's.
    var isBare: Bool {
        glass == true || bare == true
    }

    /// Text typed into a field of a still, as a person types it (``HumanTyping``): the field's row is
    /// lifted at every length of the text, the whole element whenever a word ends and its results
    /// have settled, so a `ui` layer can show it being typed. Empty text is a field waiting, its caret
    /// blinking.
    var typing: Typing?

    /// The part of the element lifted, in CSS pixels from its top-left corner: the top of a long article
    /// down to its code, say. The whole element when left out.
    var region: CGRect?

    nonisolated struct Typing: Codable, Equatable, Sendable {
        /// The field typed into, inside the element.
        var field: String
        var text: String

        /// How many of the results under the first to lift selected, pressing the down arrow once the
        /// text is typed, so a layer's ``UIContent/presses`` can move through them.
        var select: Int?
    }

    /// What's done on the page before a still is lifted: the clicks (or typing) that bring up what's
    /// lifted, like the button that opens a search dialog. `record_page`'s `click` and `type` steps.
    var before: [RecordPageRequest.Step]?

    /// Why its still-only parts can't be captured, if they can't.
    var stillProblem: String? {
        if steps != nil, isBare || typing != nil || before != nil || region != nil {
            return "glass, bare, typing, before and region are for stills; a take has its own steps."
        }
        let usable = { (step: RecordPageRequest.Step) in
            (step.selector ?? "").isEmpty == false && (step.action == "click" || (step.action == "type" && (step.text ?? "").isEmpty == false))
        }
        if let before, !before.allSatisfy(usable) {
            return "before takes click and type steps, each with a selector, a type step with text."
        }
        if let typing, typing.field.isEmpty {
            return "typing needs a field."
        }
        return nil
    }

    /// The live take's script, timed and checked as `record_page` checks its arguments, before the
    /// page has been looked at; `nil` for a still.
    func takePlan() throws(AgentToolError) -> RecordPlan? {
        guard let steps else { return nil }
        var plan = try RecordPageRequest(url: url.absoluteString, duration: duration, steps: steps, hide: hide).plan()
        plan.viewport = viewport
        return plan
    }
}

// MARK: - Codable

nonisolated extension MotionAsset: Codable {

    /// `viewport` may be left out for a 1440×900 desktop.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        selector = try container.decode(String.self, forKey: .selector)
        viewport = try container.decodeIfPresent(CGSize.self, forKey: .viewport) ?? CGSize(width: 1440, height: 900)
        steps = try container.decodeIfPresent([RecordPageRequest.Step].self, forKey: .steps)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        hide = try container.decodeIfPresent([String].self, forKey: .hide)
        glass = try container.decodeIfPresent(Bool.self, forKey: .glass)
        bare = try container.decodeIfPresent(Bool.self, forKey: .bare)
        typing = try container.decodeIfPresent(Typing.self, forKey: .typing)
        before = try container.decodeIfPresent([RecordPageRequest.Step].self, forKey: .before)
        region = try container.decodeIfPresent(CGRect.self, forKey: .region)
    }
}
